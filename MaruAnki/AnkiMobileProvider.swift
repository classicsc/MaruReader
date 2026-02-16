// AnkiMobileProvider.swift
// MaruReader
// Copyright (c) 2026  Samuel Smoker
//
// MaruReader is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// MaruReader is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with MaruReader.  If not, see <http://www.gnu.org/licenses/>.

import Foundation

public protocol AnkiMobileURLOpening: Sendable {
    func open(_ url: URL) async -> Bool
}

public actor AnkiMobileURLOpenerStore {
    public static let shared = AnkiMobileURLOpenerStore()

    private var opener: (any AnkiMobileURLOpening)?
    private var returnURL: URL?

    public func set(_ opener: (any AnkiMobileURLOpening)?) {
        self.opener = opener
    }

    public func get() -> (any AnkiMobileURLOpening)? {
        opener
    }

    public func setReturnURL(_ returnURL: URL?) {
        self.returnURL = returnURL
    }

    public func getReturnURL() -> URL? {
        returnURL
    }

    public func configure(opener: (any AnkiMobileURLOpening)?, returnURL: URL?) {
        self.opener = opener
        self.returnURL = returnURL
    }
}

enum AnkiMobileError: Error, LocalizedError, Sendable {
    case invalidConfiguration
    case invalidURL
    case openFailed

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "Missing required AnkiMobile settings."
        case .invalidURL:
            "Failed to build AnkiMobile URL."
        case .openFailed:
            "Unable to open AnkiMobile."
        }
    }
}

struct AnkiMobileProvider: AnkiProvider {
    private let urlOpener: (any AnkiMobileURLOpening)?
    private let returnURL: URL?

    init(urlOpener: (any AnkiMobileURLOpening)?, returnURL: URL? = nil) {
        self.urlOpener = urlOpener
        self.returnURL = returnURL
    }

    func addNote(
        fields: [String: [TemplateResolvedValue]],
        profileName: String,
        deckName: String,
        modelName: String,
        duplicateOptions: DuplicateDetectionOptions
    ) async throws -> AddNoteResult {
        let fieldValues = AnkiFieldValueFormatter.buildFieldValues(from: fields)
        let trimmedProfile = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let profileValue = trimmedProfile.isEmpty ? nil : trimmedProfile

        let url = try AnkiMobileURLBuilder.addNoteURL(
            profileName: profileValue,
            deckName: deckName,
            modelName: modelName,
            fields: fieldValues,
            tags: [],
            allowDuplicate: duplicateOptions.scope == .none,
            xSuccess: returnURL
        )

        if let urlOpener {
            let opened = await urlOpener.open(url)
            guard opened else {
                throw AnkiMobileError.openFailed
            }

            return AddNoteResult(ankiNoteID: nil, pendingSync: false)
        }

        return AddNoteResult(ankiNoteID: nil, pendingSync: true)
    }

    func getAnkiProfiles() async -> AnkiProfileListingResponse {
        .apiCapabilityMissing
    }

    func getAnkiDecks(forProfile _: String) async -> AnkiDeckListingResponse {
        .apiCapabilityMissing
    }

    func getAnkiModels(forProfile _: String) async -> AnkiModelListingResponse {
        .apiCapabilityMissing
    }
}

enum AnkiMobileURLBuilder {
    private static let scheme = "anki"
    private static let path = "x-callback-url/addnote"
    private static let queryAllowed: CharacterSet = .init(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    static func addNoteURL(
        profileName: String?,
        deckName: String,
        modelName: String,
        fields: [String: String],
        tags: [String],
        allowDuplicate: Bool,
        xSuccess: URL?
    ) throws -> URL {
        let trimmedDeck = deckName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDeck.isEmpty, !trimmedModel.isEmpty else {
            throw AnkiMobileError.invalidConfiguration
        }

        var pairs: [(String, String)] = []

        if let profileName, !profileName.isEmpty {
            pairs.append(("profile", profileName))
        }

        pairs.append(("type", trimmedModel))
        pairs.append(("deck", trimmedDeck))

        let sortedFields = fields.sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
        for (fieldName, value) in sortedFields {
            pairs.append(("fld\(fieldName)", value))
        }

        if !tags.isEmpty {
            pairs.append(("tags", tags.joined(separator: " ")))
        } else {
            // default tag
            pairs.append(("tags", "marureader"))
        }

        if allowDuplicate {
            pairs.append(("dupes", "1"))
        }

        if let xSuccess {
            pairs.append(("x-success", xSuccess.absoluteString))
        }

        let query = pairs.map { key, value in
            "\(encodeQuery(key))=\(encodeQuery(value))"
        }.joined(separator: "&")

        guard let url = URL(string: "\(scheme)://\(path)?\(query)") else {
            throw AnkiMobileError.invalidURL
        }

        return url
    }

    private static func encodeQuery(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: queryAllowed) ?? ""
    }
}
