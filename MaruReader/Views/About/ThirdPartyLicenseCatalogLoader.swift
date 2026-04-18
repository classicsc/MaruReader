// ThirdPartyLicenseCatalogLoader.swift
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

enum ThirdPartyComponentCategory: String, Codable, CaseIterable {
    case spm
    case rustCrate
    case contentBlocker
    case filterList
    case dictionaryData
    case ublockEmbedded

    var displayName: String {
        switch self {
        case .spm:
            String(localized: "Swift Packages")
        case .rustCrate:
            String(localized: "Rust Crates")
        case .contentBlocker:
            String(localized: "Content Blocking")
        case .filterList:
            String(localized: "Filter Lists")
        case .dictionaryData:
            String(localized: "Dictionary Data")
        case .ublockEmbedded:
            String(localized: "uBlock Embedded Components")
        }
    }

    var sortOrder: Int {
        switch self {
        case .contentBlocker:
            0
        case .filterList:
            1
        case .dictionaryData:
            2
        case .rustCrate:
            3
        case .spm:
            4
        case .ublockEmbedded:
            5
        }
    }
}

struct ThirdPartyLicenseCatalog: Codable {
    let schemaVersion: Int
    let generatedAt: String
    let components: [ThirdPartyComponent]
}

struct ThirdPartyComponent: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: ThirdPartyComponentCategory
    let homepageURL: URL?
    let sourceURL: URL?
    let version: String?
    let revision: String?
    let attribution: String?
    let notes: String?
    let licenses: [ThirdPartyLicenseDocument]
}

struct ThirdPartyLicenseDocument: Codable, Hashable {
    let title: String
    let path: String
    let referenceURL: URL?
}

enum ThirdPartyLicenseCatalogError: LocalizedError {
    case catalogNotFound
    case documentNotFound(path: String)
    case unreadableDocument(path: String)

    var errorDescription: String? {
        switch self {
        case .catalogNotFound:
            String(localized: "Could not find the third-party license catalog in the app bundle.")
        case let .documentNotFound(path):
            String.localizedStringWithFormat(
                String(localized: "Could not find the license document at %@."),
                path
            )
        case let .unreadableDocument(path):
            String.localizedStringWithFormat(
                String(localized: "Could not read the license document at %@."),
                path
            )
        }
    }
}

enum ThirdPartyLicenseCatalogLoader {
    static let catalogPath = "About/ThirdPartyLicenses/third_party_licenses.json"
    static let appLicensePath = "About/ThirdPartyLicenses/Documents/app/marureader-gpl-3.0.txt"

    static func loadCatalog(in bundle: Bundle = .main) throws -> ThirdPartyLicenseCatalog {
        guard let catalogURL = resourceURL(for: catalogPath, in: bundle) else {
            throw ThirdPartyLicenseCatalogError.catalogNotFound
        }

        let data = try Data(contentsOf: catalogURL)
        let decoder = JSONDecoder()
        return try decoder.decode(ThirdPartyLicenseCatalog.self, from: data)
    }

    static func documentText(for path: String, in bundle: Bundle = .main) throws -> String {
        guard let documentURL = documentURL(for: path, in: bundle) else {
            throw ThirdPartyLicenseCatalogError.documentNotFound(path: path)
        }

        let data = try Data(contentsOf: documentURL)

        if let content = String(data: data, encoding: .utf8) {
            return content
        }
        // Some upstream license files use Latin-1 encoding.
        if let content = String(data: data, encoding: .isoLatin1) {
            return content
        }

        throw ThirdPartyLicenseCatalogError.unreadableDocument(path: path)
    }

    static func documentURL(for path: String, in bundle: Bundle = .main) -> URL? {
        resourceURL(for: path, in: bundle)
    }

    static func resourceURL(for relativePath: String, in bundle: Bundle = .main) -> URL? {
        for candidate in candidateBundles(preferred: bundle) {
            let directURL = candidate.bundleURL.appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: directURL.path) {
                return directURL
            }

            let relativeNSString = relativePath as NSString
            let baseName = relativeNSString.lastPathComponent
            let subdirectory = relativeNSString.deletingLastPathComponent
            if let resourceURL = candidate.url(
                forResource: baseName,
                withExtension: nil,
                subdirectory: subdirectory.isEmpty ? nil : subdirectory
            ) {
                return resourceURL
            }

            if let flattenedResourceURL = candidate.url(forResource: baseName, withExtension: nil) {
                return flattenedResourceURL
            }
        }

        #if DEBUG
            if let sourceTreeURL = sourceTreeResourceURL(for: relativePath),
               FileManager.default.fileExists(atPath: sourceTreeURL.path)
            {
                return sourceTreeURL
            }
        #endif

        return nil
    }

    private static func candidateBundles(preferred: Bundle) -> [Bundle] {
        let merged = [preferred, Bundle.main] + Bundle.allBundles + Bundle.allFrameworks
        var seen = Set<String>()
        var uniqueBundles: [Bundle] = []

        for bundle in merged {
            let path = bundle.bundlePath
            if seen.insert(path).inserted {
                uniqueBundles.append(bundle)
            }
        }

        return uniqueBundles
    }

    #if DEBUG
        private static func sourceTreeResourceURL(for relativePath: String) -> URL? {
            let sourceURL = URL(fileURLWithPath: #filePath)
            let repoRoot = sourceURL
                .deletingLastPathComponent() // About
                .deletingLastPathComponent() // Views
                .deletingLastPathComponent() // MaruReader
                .deletingLastPathComponent() // repo root

            return repoRoot
                .appendingPathComponent("MaruReader")
                .appendingPathComponent(relativePath)
        }
    #endif
}
