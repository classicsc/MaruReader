#!/usr/bin/env swift

// sync-third-party-licenses.swift
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

private enum ScriptError: LocalizedError {
    case missingFile(String)
    case noCheckoutsFound
    case packageCheckoutNotFound(identity: String)
    case licenseNotFound(identity: String)
    case missingManualSnapshot(path: String)
    case conflictingGeneratedDocument(path: String)
    case requiredComponentMissing(id: String)
    case invalidRulesetURL(String)

    var errorDescription: String? {
        switch self {
        case let .missingFile(path):
            "Required file not found: \(path)"
        case .noCheckoutsFound:
            "Could not locate SwiftPM checkouts from SOURCE_PACKAGES_DIR_PATH or DerivedData."
        case let .packageCheckoutNotFound(identity):
            "Could not locate checkout directory for package identity '\(identity)'."
        case let .licenseNotFound(identity):
            "Could not find a license-like file for package '\(identity)'."
        case let .missingManualSnapshot(path):
            "Manual snapshot is missing: \(path). Run with --refresh-snapshots or add the file."
        case let .conflictingGeneratedDocument(path):
            "Generated document collision with different contents: \(path)."
        case let .requiredComponentMissing(id):
            "Required manual component is missing from generated catalog: \(id)."
        case let .invalidRulesetURL(value):
            "Invalid ruleset home URL: \(value)."
        }
    }
}

private enum ComponentCategory: String, Codable {
    case spm
    case contentBlocker
    case filterList
    case dictionaryData
    case ublockEmbedded
}

private struct Catalog: Codable {
    let schemaVersion: Int
    let generatedAt: String
    let components: [CatalogComponent]
}

private struct CatalogComponent: Codable {
    let id: String
    let name: String
    let category: ComponentCategory
    let homepageURL: URL?
    let sourceURL: URL?
    let version: String?
    let revision: String?
    let attribution: String?
    let notes: String?
    let licenses: [CatalogLicense]
}

private struct CatalogLicense: Codable {
    let title: String
    let path: String
    let referenceURL: URL?
}

private struct PackageResolved: Decodable {
    struct Pin: Decodable {
        struct State: Decodable {
            let revision: String?
            let version: String?
            let branch: String?
        }

        let identity: String
        let location: String
        let state: State
    }

    let pins: [Pin]
}

private struct ManualSourceMap: Decodable {
    struct ManualComponent: Decodable {
        struct License: Decodable {
            let title: String
            let outputPath: String
            let snapshotPath: String
            let referenceURL: URL?
            let refreshURL: URL?
            let refreshLocalPath: String?
        }

        let id: String
        let name: String
        let category: ComponentCategory
        let homepageURL: URL?
        let sourceURL: URL?
        let version: String?
        let revision: String?
        let attribution: String?
        let notes: String?
        let licenses: [License]
    }

    let schemaVersion: Int
    let components: [ManualComponent]
}

private struct Ruleset: Decodable {
    let id: String
    let name: String
    let enabled: Bool?
    let homeURL: String?
}

private let requiredManualComponentIDs: Set<String> = [
    "manual-ublock-origin-lite",
    "manual-uassets-filters",
    "manual-easylist-easyprivacy",
    "manual-adguard-filters",
    "manual-jitendex",
    "manual-kanji-alive",
    "manual-material-symbols-outlined",
]

private let resourcePrefix = "About/ThirdPartyLicenses/Documents"

private func run() throws {
    let refreshSnapshots = CommandLine.arguments.contains("--refresh-snapshots")
    let fileManager = FileManager.default
    let rootURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)

    let packageResolvedURL = rootURL.appendingPathComponent("MaruReader.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved")
    let manualSourcesURL = rootURL.appendingPathComponent("scripts/third-party-manual-sources.json")
    let ublockRulesetsURL = rootURL.appendingPathComponent("External/ublock-rulesets.json")
    let appCopyingURL = rootURL.appendingPathComponent("COPYING")

    let aboutRootURL = rootURL.appendingPathComponent("MaruReader/About/ThirdPartyLicenses")
    let documentsRootURL = aboutRootURL.appendingPathComponent("Documents")
    let catalogURL = aboutRootURL.appendingPathComponent("third_party_licenses.json")

    try requireFile(packageResolvedURL.path)
    try requireFile(manualSourcesURL.path)
    try requireFile(ublockRulesetsURL.path)
    try requireFile(appCopyingURL.path)

    if fileManager.fileExists(atPath: documentsRootURL.path) {
        try fileManager.removeItem(at: documentsRootURL)
    }
    try fileManager.createDirectory(at: documentsRootURL, withIntermediateDirectories: true)

    let appLicenseOutput = documentsRootURL.appendingPathComponent("app/marureader-gpl-3.0.txt")
    try copyDocument(from: appCopyingURL, to: appLicenseOutput)

    let packageResolved = try decode(PackageResolved.self, from: packageResolvedURL)
    let manualSources = try decode(ManualSourceMap.self, from: manualSourcesURL)
    let rulesets = try decode([Ruleset].self, from: ublockRulesetsURL)

    if refreshSnapshots {
        try refreshManualSnapshots(manualSources, rootURL: rootURL)
    }

    let checkoutsRootURL = try resolveCheckoutsRoot(rootURL: rootURL)
    let spmComponents = try buildSPMComponents(
        packageResolved: packageResolved,
        checkoutsRootURL: checkoutsRootURL,
        rootURL: rootURL,
        documentsRootURL: documentsRootURL
    )

    let providerNotes = try buildProviderNotes(rulesets: rulesets)
    let manualComponents = try buildManualComponents(
        manualSources: manualSources,
        rootURL: rootURL,
        documentsRootURL: documentsRootURL,
        providerNotes: providerNotes
    )

    let ublockEmbeddedComponents = try buildUBLockEmbeddedComponents(
        rootURL: rootURL,
        documentsRootURL: documentsRootURL
    )

    let manualIDs = Set(manualComponents.map(\.id))
    for requiredID in requiredManualComponentIDs where !manualIDs.contains(requiredID) {
        throw ScriptError.requiredComponentMissing(id: requiredID)
    }

    let expectedSPMIDs = Set(packageResolved.pins.map { "spm-\($0.identity)" })
    let generatedSPMIDs = Set(spmComponents.map(\.id))
    if expectedSPMIDs != generatedSPMIDs {
        let missing = expectedSPMIDs.subtracting(generatedSPMIDs).sorted()
        let extra = generatedSPMIDs.subtracting(expectedSPMIDs).sorted()
        if !missing.isEmpty {
            throw ScriptError.requiredComponentMissing(id: "missing SPM IDs: \(missing.joined(separator: ", "))")
        }
        if !extra.isEmpty {
            throw ScriptError.requiredComponentMissing(id: "unexpected SPM IDs: \(extra.joined(separator: ", "))")
        }
    }

    let components = (manualComponents + spmComponents + ublockEmbeddedComponents)
        .sorted { lhs, rhs in
            lhs.id < rhs.id
        }

    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    let catalog = Catalog(
        schemaVersion: 1,
        generatedAt: dateFormatter.string(from: Date()),
        components: components
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let catalogData = try encoder.encode(catalog)
    try fileManager.createDirectory(at: aboutRootURL, withIntermediateDirectories: true)
    try catalogData.write(to: catalogURL)

    print("Generated catalog at \(catalogURL.path)")
    print("SPM components: \(spmComponents.count)")
    print("Manual components: \(manualComponents.count)")
    print("uBlock embedded components: \(ublockEmbeddedComponents.count)")
}

private func requireFile(_ path: String) throws {
    guard FileManager.default.fileExists(atPath: path) else {
        throw ScriptError.missingFile(path)
    }
}

private func decode<T: Decodable>(_: T.Type, from url: URL) throws -> T {
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(T.self, from: data)
}

private func resolveCheckoutsRoot(rootURL _: URL) throws -> URL {
    let fileManager = FileManager.default

    if let sourcePackagesDir = ProcessInfo.processInfo.environment["SOURCE_PACKAGES_DIR_PATH"], !sourcePackagesDir.isEmpty {
        let checkoutsURL = URL(fileURLWithPath: sourcePackagesDir).appendingPathComponent("checkouts")
        if fileManager.fileExists(atPath: checkoutsURL.path) {
            return checkoutsURL
        }
    }

    let derivedDataRoot = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Developer/Xcode/DerivedData")

    guard let entries = try? fileManager.contentsOfDirectory(
        at: derivedDataRoot,
        includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) else {
        throw ScriptError.noCheckoutsFound
    }

    let candidateCheckouts: [URL] = entries
        .filter { $0.lastPathComponent.hasPrefix("MaruReader-") }
        .map { $0.appendingPathComponent("SourcePackages/checkouts") }
        .filter { fileManager.fileExists(atPath: $0.path) }

    guard !candidateCheckouts.isEmpty else {
        throw ScriptError.noCheckoutsFound
    }

    let sorted = candidateCheckouts.sorted { lhs, rhs in
        let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        return lhsDate > rhsDate
    }

    guard let selected = sorted.first else {
        throw ScriptError.noCheckoutsFound
    }

    return selected
}

private func buildSPMComponents(
    packageResolved: PackageResolved,
    checkoutsRootURL: URL,
    rootURL _: URL,
    documentsRootURL: URL
) throws -> [CatalogComponent] {
    let fileManager = FileManager.default
    let checkoutDirectories = try fileManager.contentsOfDirectory(at: checkoutsRootURL, includingPropertiesForKeys: nil)
    let checkoutMap = Dictionary(uniqueKeysWithValues: checkoutDirectories.map { ($0.lastPathComponent.lowercased(), $0) })

    return try packageResolved.pins.sorted { $0.identity < $1.identity }.map { pin in
        guard let checkoutURL = checkoutMap[pin.identity.lowercased()] else {
            throw ScriptError.packageCheckoutNotFound(identity: pin.identity)
        }

        let licenseFiles = try findLicenseLikeFiles(in: checkoutURL, maxDepth: 3)
        guard let primaryLicense = selectPrimaryLicenseFile(licenseFiles, root: checkoutURL) else {
            throw ScriptError.licenseNotFound(identity: pin.identity)
        }

        let outputPath = "spm/spm-\(slug(pin.identity))-\(slug(primaryLicense.lastPathComponent)).txt"
        let outputURL = documentsRootURL.appendingPathComponent(outputPath)
        try copyDocument(from: primaryLicense, to: outputURL)

        let versionText = pin.state.version

        return CatalogComponent(
            id: "spm-\(pin.identity)",
            name: checkoutURL.lastPathComponent,
            category: .spm,
            homepageURL: URL(string: pin.location),
            sourceURL: URL(string: pin.location),
            version: versionText,
            revision: pin.state.revision,
            attribution: nil,
            notes: nil,
            licenses: [
                CatalogLicense(
                    title: primaryLicense.lastPathComponent,
                    path: "\(resourcePrefix)/\(outputPath)",
                    referenceURL: URL(string: pin.location)
                ),
            ]
        )
    }
}

private func refreshManualSnapshots(_ manualSources: ManualSourceMap, rootURL: URL) throws {
    let fileManager = FileManager.default

    for component in manualSources.components {
        for license in component.licenses {
            let snapshotURL = rootURL.appendingPathComponent(license.snapshotPath)
            try fileManager.createDirectory(at: snapshotURL.deletingLastPathComponent(), withIntermediateDirectories: true)

            if let refreshURL = license.refreshURL {
                let data = try Data(contentsOf: refreshURL)
                try data.write(to: snapshotURL)
            } else if let refreshLocalPath = license.refreshLocalPath {
                let sourceURL = rootURL.appendingPathComponent(refreshLocalPath)
                try copyDocument(from: sourceURL, to: snapshotURL)
            }
        }
    }
}

private func buildManualComponents(
    manualSources: ManualSourceMap,
    rootURL: URL,
    documentsRootURL: URL,
    providerNotes: [String: String]
) throws -> [CatalogComponent] {
    try manualSources.components.sorted { $0.id < $1.id }.map { component in
        let notes = [
            component.notes,
            providerNotes[component.id],
        ]
        .compactMap(\.self)
        .joined(separator: "\n")

        let licenses = try component.licenses.map { license in
            let snapshotURL = rootURL.appendingPathComponent(license.snapshotPath)
            guard FileManager.default.fileExists(atPath: snapshotURL.path) else {
                throw ScriptError.missingManualSnapshot(path: license.snapshotPath)
            }

            let outputURL = documentsRootURL.appendingPathComponent(license.outputPath)
            try copyDocument(from: snapshotURL, to: outputURL)

            return CatalogLicense(
                title: license.title,
                path: "\(resourcePrefix)/\(license.outputPath)",
                referenceURL: license.referenceURL
            )
        }

        return CatalogComponent(
            id: component.id,
            name: component.name,
            category: component.category,
            homepageURL: component.homepageURL,
            sourceURL: component.sourceURL,
            version: component.version,
            revision: component.revision,
            attribution: component.attribution,
            notes: notes.isEmpty ? nil : notes,
            licenses: licenses
        )
    }
}

private func buildProviderNotes(rulesets: [Ruleset]) throws -> [String: String] {
    var groupedNames: [String: [String]] = [
        "manual-uassets-filters": [],
        "manual-easylist-easyprivacy": [],
        "manual-adguard-filters": [],
    ]

    for ruleset in rulesets where ruleset.enabled ?? false {
        guard let homeURLValue = ruleset.homeURL else {
            continue
        }

        guard let homeURL = URL(string: homeURLValue) else {
            throw ScriptError.invalidRulesetURL(homeURLValue)
        }

        let descriptor = "\(ruleset.name) (\(ruleset.id))"

        if homeURLValue.contains("uBlockOrigin/uAssets") {
            groupedNames["manual-uassets-filters", default: []].append(descriptor)
        } else if homeURL.host == "easylist.to" {
            groupedNames["manual-easylist-easyprivacy", default: []].append(descriptor)
        } else if homeURLValue.lowercased().contains("adguardteam/adguardfilters") {
            groupedNames["manual-adguard-filters", default: []].append(descriptor)
        }
    }

    return groupedNames.compactMapValues { values in
        guard !values.isEmpty else { return nil }
        let sortedValues = values.sorted()
        return "Enabled rulesets from External/ublock-rulesets.json: \(sortedValues.joined(separator: ", "))."
    }
}

private func buildUBLockEmbeddedComponents(
    rootURL: URL,
    documentsRootURL: URL
) throws -> [CatalogComponent] {
    let ublockRoot = rootURL.appendingPathComponent("External/uBlock")
    try requireFile(ublockRoot.path)

    let licenseFiles = try findLicenseLikeFiles(in: ublockRoot, maxDepth: Int.max)
        .filter { fileURL in
            let relative = fileURL.path.replacingOccurrences(of: ublockRoot.path + "/", with: "")
            return relative != "LICENSE.txt" && !relative.hasPrefix("dist/build/")
        }
        .sorted { lhs, rhs in
            lhs.path < rhs.path
        }

    return try licenseFiles.map { licenseFile in
        let relativePath = licenseFile.path.replacingOccurrences(of: ublockRoot.path + "/", with: "")
        let outputPath = "ublock-embedded/ublock-embedded-\(slug(relativePath)).txt"
        let outputURL = documentsRootURL.appendingPathComponent(outputPath)
        try copyDocument(from: licenseFile, to: outputURL)

        let id = "ublock-embedded-\(slug(relativePath))"
        let sourceURL = URL(string: "https://github.com/gorhill/uBlock/blob/master/\(relativePath)")
        let embeddedName = embeddedComponentName(for: relativePath)

        return CatalogComponent(
            id: id,
            name: embeddedName,
            category: .ublockEmbedded,
            homepageURL: URL(string: "https://github.com/gorhill/uBlock"),
            sourceURL: sourceURL,
            version: nil,
            revision: nil,
            attribution: "Various authors (see included license text)",
            notes: "Discovered automatically from External/uBlock.",
            licenses: [
                CatalogLicense(
                    title: licenseFile.lastPathComponent,
                    path: "\(resourcePrefix)/\(outputPath)",
                    referenceURL: sourceURL
                ),
            ]
        )
    }
}

private func copyDocument(from sourceURL: URL, to destinationURL: URL) throws {
    let fileManager = FileManager.default
    try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)

    let sourceData = try Data(contentsOf: sourceURL)
    if fileManager.fileExists(atPath: destinationURL.path) {
        let existingData = try Data(contentsOf: destinationURL)
        if existingData != sourceData {
            throw ScriptError.conflictingGeneratedDocument(path: destinationURL.path)
        }
        return
    }

    try sourceData.write(to: destinationURL)
}

private func findLicenseLikeFiles(in directoryURL: URL, maxDepth: Int) throws -> [URL] {
    var results: [URL] = []
    try walkDirectory(in: directoryURL, currentDepth: 0, maxDepth: maxDepth, results: &results)
    return results
}

private func walkDirectory(in directoryURL: URL, currentDepth: Int, maxDepth: Int, results: inout [URL]) throws {
    guard currentDepth <= maxDepth else { return }

    let contents = try FileManager.default.contentsOfDirectory(
        at: directoryURL,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    )

    for itemURL in contents {
        let resourceValues = try itemURL.resourceValues(forKeys: [.isDirectoryKey])
        if resourceValues.isDirectory == true {
            try walkDirectory(
                in: itemURL,
                currentDepth: currentDepth + 1,
                maxDepth: maxDepth,
                results: &results
            )
        } else if isLicenseLikeFile(name: itemURL.lastPathComponent) {
            results.append(itemURL)
        }
    }
}

private func isLicenseLikeFile(name: String) -> Bool {
    let upper = name.uppercased()
    return upper.hasPrefix("LICENSE") || upper.hasPrefix("COPYING") || upper.hasPrefix("NOTICE") || upper == "UNLICENSE"
}

private func selectPrimaryLicenseFile(_ files: [URL], root: URL) -> URL? {
    files.min { lhs, rhs in
        let lhsScore = licenseSelectionScore(for: lhs, root: root)
        let rhsScore = licenseSelectionScore(for: rhs, root: root)
        if lhsScore != rhsScore {
            return lhsScore < rhsScore
        }
        return lhs.path < rhs.path
    }
}

private func licenseSelectionScore(for fileURL: URL, root: URL) -> Int {
    let relativePath = fileURL.path.replacingOccurrences(of: root.path + "/", with: "")
    let depth = relativePath.split(separator: "/").count
    let isRoot = depth == 1 ? 0 : 1
    return isRoot * 1000 + depth
}

private func slug(_ value: String) -> String {
    value
        .lowercased()
        .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
}

private func embeddedComponentName(for relativePath: String) -> String {
    let components = relativePath.split(separator: "/")
    guard components.count >= 2 else { return relativePath }
    return String(components[components.count - 2])
}

do {
    try run()
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
