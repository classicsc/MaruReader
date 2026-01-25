// AnkiConnectProvider.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import Foundation

/// Errors that can occur when communicating with Anki-Connect.
enum AnkiConnectError: Error, Sendable, Equatable, LocalizedError {
    /// The Anki-Connect API returned an error.
    case apiError(String)
    /// Failed to connect to Anki-Connect.
    case connectionFailed(Error)
    /// The response from Anki-Connect was malformed.
    case invalidResponse
    /// Permission was denied by Anki-Connect.
    case permissionDenied
    /// API key is required but not provided.
    case apiKeyRequired
    /// A duplicate note was detected.
    case duplicateNote
    /// The requested profile is not currently active in Anki.
    case profileMismatch(expected: String, actual: String)
    /// Failed to read a local media file.
    case mediaReadFailed(URL)

    var errorDescription: String? {
        switch self {
        case let .apiError(message):
            "Anki-Connect error: \(message)"
        case let .connectionFailed(error):
            "Failed to connect to Anki-Connect: \(error.localizedDescription)"
        case .invalidResponse:
            "Received an invalid response from Anki-Connect."
        case .permissionDenied:
            "Permission denied by Anki-Connect. Please allow access when prompted in Anki."
        case .apiKeyRequired:
            "An API key is required. Please enter your Anki-Connect API key."
        case .duplicateNote:
            "A note with this content already exists."
        case let .profileMismatch(expected, actual):
            "Profile mismatch: expected \"\(expected)\" but \"\(actual)\" is active. Please switch profiles in Anki."
        case let .mediaReadFailed(url):
            "Failed to read media file: \(url.lastPathComponent)"
        }
    }

    static func == (lhs: AnkiConnectError, rhs: AnkiConnectError) -> Bool {
        switch (lhs, rhs) {
        case let (.apiError(lhsString), .apiError(rhsString)):
            return lhsString == rhsString
        case let (.connectionFailed(lhsError), .connectionFailed(rhsError)):
            let lhsNsError = lhsError as NSError
            let rhsNsError = rhsError as NSError
            return lhsNsError.domain == rhsNsError.domain && lhsNsError.code == rhsNsError.code
        case (.invalidResponse, .invalidResponse),
             (.permissionDenied, .permissionDenied),
             (.apiKeyRequired, .apiKeyRequired),
             (.duplicateNote, .duplicateNote):
            return true
        case let (.profileMismatch(lhsExp, lhsAct), .profileMismatch(rhsExp, rhsAct)):
            return lhsExp == rhsExp && lhsAct == rhsAct
        case let (.mediaReadFailed(lhsUrl), .mediaReadFailed(rhsUrl)):
            return lhsUrl == rhsUrl
        default:
            return false
        }
    }
}

/// An implementation of `AnkiProvider` that communicates with Anki via Anki-Connect.
struct AnkiConnectProvider: AnkiProvider, Sendable {
    private let host: String
    private let port: Int
    private let apiKey: String?
    private let network: any NetworkProviding

    /// The API version to use for requests.
    private static let apiVersion = 6

    /// Creates a new Anki-Connect provider.
    ///
    /// - Parameters:
    ///   - host: The hostname where Anki-Connect is running (e.g., "localhost").
    ///   - port: The port number (default: 8765).
    ///   - apiKey: Optional API key for authentication.
    ///   - network: The network provider to use for requests (injectable for testing).
    init(
        host: String,
        port: Int = 8765,
        apiKey: String? = nil,
        network: any NetworkProviding = URLSession.shared
    ) async throws {
        self.host = host
        self.port = port
        self.apiKey = apiKey
        self.network = network
        let permissionResponse = try await requestPermission() // Ensure permission is granted at initialization
        if permissionResponse.requiresApiKey, apiKey == nil {
            throw AnkiConnectError.apiKeyRequired
        }
    }

    /// Requests permission from Anki-Connect.
    ///
    /// This should be called before making other API calls to ensure the connection is allowed.
    /// - Returns: A `PermissionResponse` indicating whether permission was granted.
    func requestPermission() async throws -> PermissionResponse {
        let request = AnkiConnectRequest(action: "requestPermission")
        let response: AnkiConnectResponse<PermissionResult> = try await send(request)

        guard let result = response.result else {
            throw AnkiConnectError.invalidResponse
        }

        guard result.permission == "granted" else {
            throw AnkiConnectError.permissionDenied
        }

        return PermissionResponse(
            requiresApiKey: result.requireApiKey ?? false,
            version: result.version
        )
    }

    func addNote(
        fields: [String: [TemplateResolvedValue]],
        profileName _: String,
        deckName: String,
        modelName: String,
        duplicateOptions: DuplicateDetectionOptions
    ) async throws -> AddNoteResult {
        // Combine resolved values into field content and collect media
        var fieldContent: [String: String] = [:]
        var mediaItems: [MediaItem] = []

        for (fieldName, values) in fields {
            var combinedText = ""

            for value in values {
                if let text = value.text {
                    combinedText += text
                }

                // If the value has text, media files are already referenced inline (e.g., glossary images).
                // Only specify the field name when there's no text, so Anki-Connect inserts the img tag.
                let targetField: String? = value.text == nil ? fieldName : nil

                for (filename, url) in value.mediaFiles {
                    let mediaItem = try await prepareMediaItem(
                        filename: filename,
                        url: url,
                        fieldName: targetField
                    )
                    mediaItems.append(mediaItem)
                }
            }

            fieldContent[fieldName] = combinedText
        }

        // Build the note parameters
        var noteParams: [String: Any] = [
            "deckName": deckName,
            "modelName": modelName,
            "fields": fieldContent,
            "tags": ["marureader"] as [String],
        ]

        // Configure duplicate handling
        switch duplicateOptions.scope {
        case .none:
            noteParams["options"] = [
                "allowDuplicate": true,
            ]
        case .deck:
            let duplicateScopeOptions: [String: Any] = [
                "deckName": duplicateOptions.deckName ?? deckName,
                "checkChildren": duplicateOptions.includeChildDecks,
                "checkAllModels": duplicateOptions.checkAllModels,
            ]
            noteParams["options"] = [
                "allowDuplicate": false,
                "duplicateScope": "deck",
                "duplicateScopeOptions": duplicateScopeOptions,
            ]
        case .collection:
            noteParams["options"] = [
                "allowDuplicate": false,
                "duplicateScope": "collection",
                "duplicateScopeOptions": [
                    "checkAllModels": duplicateOptions.checkAllModels,
                ],
            ]
        }

        // Add media items grouped by type
        let pictures = mediaItems.filter { $0.type == .image }
        let audio = mediaItems.filter { $0.type == .audio }
        let video = mediaItems.filter { $0.type == .video }

        if !pictures.isEmpty {
            noteParams["picture"] = pictures.map { $0.toDictionary() }
        }
        if !audio.isEmpty {
            noteParams["audio"] = audio.map { $0.toDictionary() }
        }
        if !video.isEmpty {
            noteParams["video"] = video.map { $0.toDictionary() }
        }

        let request = AnkiConnectRequest(
            action: "addNote",
            params: ["note": noteParams]
        )

        let response: AnkiConnectResponse<Int64?> = try await send(request)

        if let error = response.error {
            if error.lowercased().contains("duplicate") {
                throw AnkiConnectError.duplicateNote
            }
            throw AnkiConnectError.apiError(error)
        }

        return AddNoteResult(ankiNoteID: response.result ?? nil, pendingSync: false)
    }

    func getAnkiProfiles() async -> AnkiProfileListingResponse {
        do {
            let profilesRequest = AnkiConnectRequest(action: "getProfiles")
            let profilesResponse: AnkiConnectResponse<[String]> = try await send(profilesRequest)
            guard let profiles = profilesResponse.result else {
                throw AnkiConnectError.invalidResponse
            }

            let activeProfileRequest = AnkiConnectRequest(action: "getActiveProfile")
            let activeProfileResponse: AnkiConnectResponse<String> = try await send(activeProfileRequest)
            guard let activeProfile = activeProfileResponse.result else {
                throw AnkiConnectError.invalidResponse
            }

            let metas = profiles.map { name in
                AnkiProfileMeta(id: name, isActiveProfile: name == activeProfile)
            }

            return .success(metas)
        } catch {
            return .failure(error)
        }
    }

    func getAnkiDecks(forProfile profileName: String) async -> AnkiDeckListingResponse {
        do {
            try await verifyActiveProfile(profileName)

            let request = AnkiConnectRequest(action: "deckNamesAndIds")
            let response: AnkiConnectResponse<[String: Int]> = try await send(request)

            guard let decks = response.result else {
                throw AnkiConnectError.invalidResponse
            }

            let metas = decks.map { name, id in
                AnkiDeckMeta(id: String(id), name: name, profileName: profileName)
            }.sorted { $0.name < $1.name }

            return .success(metas)
        } catch {
            return .failure(error)
        }
    }

    func getAnkiModels(forProfile profileName: String) async -> AnkiModelListingResponse {
        do {
            try await verifyActiveProfile(profileName)

            // 1. Get all models
            let modelsRequest = AnkiConnectRequest(action: "modelNamesAndIds")
            let modelsResponse: AnkiConnectResponse<[String: Int]> = try await send(modelsRequest)

            guard let models = modelsResponse.result else {
                throw AnkiConnectError.invalidResponse
            }

            // 2. Get fields for each model using 'multi'
            let sortedModels = models.sorted { $0.key < $1.key }
            let actions = sortedModels.map { name, _ in
                [
                    "action": "modelFieldNames",
                    "version": Self.apiVersion,
                    "params": ["modelName": name],
                ] as [String: Any]
            }

            let multiRequest = AnkiConnectRequest(
                action: "multi",
                params: ["actions": actions]
            )

            // The result is [AnkiConnectResponse<[String]>]
            let multiResponse: AnkiConnectResponse<[AnkiConnectResponse<[String]>]> = try await send(multiRequest)

            guard let fieldResponses = multiResponse.result else {
                throw AnkiConnectError.invalidResponse
            }

            guard fieldResponses.count == sortedModels.count else {
                throw AnkiConnectError.invalidResponse
            }

            var metas: [AnkiModelMeta] = []
            for (index, (name, id)) in sortedModels.enumerated() {
                let fieldResponse = fieldResponses[index]
                guard let fields = fieldResponse.result else {
                    // For now, assume valid model implies valid fields.
                    throw AnkiConnectError.invalidResponse
                }

                metas.append(AnkiModelMeta(
                    id: String(id),
                    name: name,
                    profileName: profileName,
                    fields: fields
                ))
            }

            return .success(metas)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Private Helpers

    private func verifyActiveProfile(_ profileName: String) async throws {
        let request = AnkiConnectRequest(action: "getActiveProfile")
        let response: AnkiConnectResponse<String> = try await send(request)

        guard let activeProfile = response.result else {
            throw AnkiConnectError.invalidResponse
        }

        guard activeProfile == profileName else {
            throw AnkiConnectError.profileMismatch(expected: profileName, actual: activeProfile)
        }
    }

    private func send<T: Decodable>(_ request: AnkiConnectRequest) async throws -> AnkiConnectResponse<T> {
        let url = URL(string: "https://\(host):\(port)")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body = request.toDictionary()
        body["version"] = Self.apiVersion
        if let apiKey {
            body["key"] = apiKey
        }

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        do {
            (data, _) = try await network.data(for: urlRequest)
        } catch {
            throw AnkiConnectError.connectionFailed(error)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(AnkiConnectResponse<T>.self, from: data)
    }

    private func prepareMediaItem(
        filename: String,
        url: URL,
        fieldName: String?
    ) async throws -> MediaItem {
        // Derive extension from the URL if the filename doesn't have one
        var finalFilename = filename
        let filenameExtension = (filename as NSString).pathExtension
        if filenameExtension.isEmpty {
            let urlExtension = url.pathExtension
            if !urlExtension.isEmpty {
                finalFilename = "\(filename).\(urlExtension)"
            }
        }

        let mediaType = MediaType.from(filename: finalFilename)
        let targetFields: [String] = fieldName.map { [$0] } ?? []

        if url.isFileURL {
            // Base64 encode local files
            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                throw AnkiConnectError.mediaReadFailed(url)
            }
            let base64 = data.base64EncodedString()

            return MediaItem(
                filename: finalFilename,
                source: .data(base64),
                fields: targetFields,
                type: mediaType
            )
        } else {
            // Use URL for remote files
            return MediaItem(
                filename: finalFilename,
                source: .url(url.absoluteString),
                fields: targetFields,
                type: mediaType
            )
        }
    }
}

// MARK: - Request/Response Types

private struct AnkiConnectRequest {
    let action: String
    let params: [String: Any]?

    init(action: String, params: [String: Any]? = nil) {
        self.action = action
        self.params = params
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["action": action]
        if let params {
            dict["params"] = params
        }
        return dict
    }
}

private struct AnkiConnectResponse<T: Decodable>: Decodable {
    let result: T?
    let error: String?
}

private struct PermissionResult: Decodable {
    let permission: String
    let requireApiKey: Bool?
    let version: Int?
}

/// The result of a permission request to Anki-Connect.
struct PermissionResponse: Sendable {
    /// Whether the API requires an API key for authentication.
    let requiresApiKey: Bool
    /// The API version supported by Anki-Connect.
    let version: Int?
}

// MARK: - Media Types

private enum MediaType {
    case image
    case audio
    case video

    static func from(filename: String) -> MediaType {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "mp3", "wav", "ogg", "flac", "m4a", "aac":
            return .audio
        case "mp4", "mov", "avi", "mkv", "webm":
            return .video
        default:
            return .image
        }
    }
}

private enum MediaSource {
    case data(String)
    case url(String)
}

private struct MediaItem {
    let filename: String
    let source: MediaSource
    let fields: [String]
    let type: MediaType

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "filename": filename,
            "fields": fields,
        ]

        switch source {
        case let .data(base64):
            dict["data"] = base64
        case let .url(urlString):
            dict["url"] = urlString
        }

        return dict
    }
}
