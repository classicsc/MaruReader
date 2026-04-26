#!/usr/bin/env swift

// sync-third-party-licenses.swift
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

private enum ScriptError: LocalizedError {
    case missingFile(String)
    case noCheckoutsFound
    case packageCheckoutNotFound(identity: String)
    case licenseNotFound(identity: String)
    case missingManualSnapshot(path: String)
    case missingGeneratedSnapshot(path: String)
    case missingGeneratedLicense(crate: String)
    case conflictingGeneratedDocument(path: String)
    case requiredComponentMissing(id: String)
    case invalidRulesetURL(String)
    case commandFailed(command: String, exitCode: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case let .missingFile(path):
            return "Required file not found: \(path)"
        case .noCheckoutsFound:
            return "Could not locate SwiftPM checkouts from SOURCE_PACKAGES_DIR_PATH or DerivedData."
        case let .packageCheckoutNotFound(identity):
            return "Could not locate checkout directory for package identity '\(identity)'."
        case let .licenseNotFound(identity):
            return "Could not find a license-like file for package '\(identity)'."
        case let .missingManualSnapshot(path):
            return "Manual snapshot is missing: \(path). Run with --refresh-snapshots or add the file."
        case let .missingGeneratedSnapshot(path):
            return "Generated snapshot is missing: \(path). Run with --refresh-snapshots."
        case let .missingGeneratedLicense(crate):
            return "Generated Rust license data is missing for crate '\(crate)'."
        case let .conflictingGeneratedDocument(path):
            return "Generated document collision with different contents: \(path)."
        case let .requiredComponentMissing(id):
            return "Required manual component is missing from generated catalog: \(id)."
        case let .invalidRulesetURL(value):
            return "Invalid ruleset home URL: \(value)."
        case let .commandFailed(command, exitCode, stderr):
            if stderr.isEmpty {
                return "Command failed with exit code \(exitCode): \(command)"
            }
            return "Command failed with exit code \(exitCode): \(command)\n\(stderr)"
        }
    }
}

private enum ComponentCategory: String, Codable {
    case spm
    case rustCrate
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

private struct CargoAboutSnapshot: Decodable {
    struct License: Decodable {
        struct UsedBy: Decodable {
            struct PackageReference: Decodable {
                let name: String
                let version: String
            }

            let krate: PackageReference

            private enum CodingKeys: String, CodingKey {
                case krate = "crate"
            }
        }

        let name: String
        let id: String
        let text: String
        let sourcePath: String?
        let usedBy: [UsedBy]

        private enum CodingKeys: String, CodingKey {
            case name
            case id
            case text
            case sourcePath = "source_path"
            case usedBy = "used_by"
        }
    }

    struct CrateEntry: Decodable {
        struct Package: Decodable {
            struct Target: Decodable {
                let kind: [String]
            }

            let name: String
            let version: String
            let authors: [String]
            let source: String?
            let homepage: String?
            let repository: String?
            let documentation: String?
            let targets: [Target]
        }

        let package: Package
        let license: String
    }

    let licenses: [License]
    let crates: [CrateEntry]
}

private struct RustLicenseSource {
    let crateDirectoryPath: String
    let snapshotPath: String
    let lockfilePath: String
}

private struct RustComponentAccumulator {
    let component: CatalogComponent
    var lockfilePaths: Set<String>
}

private let requiredManualComponentIDs: Set<String> = [
    "manual-ublock-origin-lite",
    "manual-uassets-filters",
    "manual-easylist-easyprivacy",
    "manual-adguard-filters",
    "manual-material-symbols-outlined",
]

private let resourcePrefix = "About/ThirdPartyLicenses/Documents"
private let rustAboutConfigPath = "MaruSudachiFFI/about.toml"
private let rustLicenseSources: [RustLicenseSource] = [
    RustLicenseSource(
        crateDirectoryPath: "MaruSudachiFFI",
        snapshotPath: "scripts/third-party-license-snapshots/rust/maru-sudachi-ffi-cargo-about.json",
        lockfilePath: "MaruSudachiFFI/Cargo.lock"
    ),
    RustLicenseSource(
        crateDirectoryPath: "MaruMarkFFI",
        snapshotPath: "scripts/third-party-license-snapshots/rust/maru-mark-ffi-cargo-about.json",
        lockfilePath: "MaruMarkFFI/Cargo.lock"
    ),
]

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
        try refreshRustSnapshots(rootURL: rootURL)
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
    let rustComponents = try buildRustComponents(
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

    let components = (manualComponents + spmComponents + rustComponents + ublockEmbeddedComponents)
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
    print("Rust components: \(rustComponents.count)")
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

private func refreshRustSnapshots(rootURL: URL) throws {
    let fileManager = FileManager.default
    let configURL = rootURL.appendingPathComponent(rustAboutConfigPath)

    try requireFile(configURL.path)

    for source in rustLicenseSources {
        let crateURL = rootURL.appendingPathComponent(source.crateDirectoryPath)
        let snapshotURL = rootURL.appendingPathComponent(source.snapshotPath)

        try fileManager.createDirectory(at: snapshotURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        try runCommand(
            [
                "cargo",
                "about",
                "-L",
                "error",
                "generate",
                "--format",
                "json",
                "--locked",
                "-c",
                configURL.path,
                "-o",
                snapshotURL.path,
            ],
            currentDirectoryURL: crateURL
        )
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

private func buildRustComponents(
    rootURL: URL,
    documentsRootURL: URL
) throws -> [CatalogComponent] {
    var componentsByID: [String: RustComponentAccumulator] = [:]

    for source in rustLicenseSources {
        let snapshotURL = rootURL.appendingPathComponent(source.snapshotPath)
        guard FileManager.default.fileExists(atPath: snapshotURL.path) else {
            throw ScriptError.missingGeneratedSnapshot(path: source.snapshotPath)
        }

        let snapshot = try decode(CargoAboutSnapshot.self, from: snapshotURL)
        var licensesByPackageKey: [String: [CargoAboutSnapshot.License]] = [:]

        for license in snapshot.licenses {
            for usage in license.usedBy {
                licensesByPackageKey[packageKey(name: usage.krate.name, version: usage.krate.version), default: []].append(license)
            }
        }

        let crates = snapshot.crates
            .filter { $0.license != "Unknown" && hasLibraryLikeTarget($0.package.targets) }
            .sorted { lhs, rhs in
                if lhs.package.name != rhs.package.name {
                    return lhs.package.name < rhs.package.name
                }
                return lhs.package.version < rhs.package.version
            }

        for crate in crates {
            let package = crate.package
            let key = packageKey(name: package.name, version: package.version)
            guard let crateLicenses = licensesByPackageKey[key], !crateLicenses.isEmpty else {
                throw ScriptError.missingGeneratedLicense(crate: key)
            }

            let sortedLicenses = crateLicenses.sorted { lhs, rhs in
                if lhs.id != rhs.id {
                    return lhs.id < rhs.id
                }
                let lhsPath = lhs.sourcePath ?? ""
                let rhsPath = rhs.sourcePath ?? ""
                if lhsPath != rhsPath {
                    return lhsPath < rhsPath
                }
                return lhs.text < rhs.text
            }

            let componentID = "rust-\(slug(package.name))-\(slug(package.version))"
            if var existing = componentsByID[componentID] {
                existing.lockfilePaths.insert(source.lockfilePath)
                componentsByID[componentID] = existing
                continue
            }

            let componentSourceURL = preferredRustSourceURL(for: package)
            let componentHomepageURL = preferredRustHomepageURL(for: package)
            let baseOutputPath = "rust/rust-\(slug(package.name))-\(slug(package.version))"
            let licenses = try sortedLicenses.enumerated().map { index, license in
                let outputPath = "\(baseOutputPath)-\(slug(license.id))-\(index + 1).txt"
                let outputURL = documentsRootURL.appendingPathComponent(outputPath)
                try writeDocument(Data(license.text.utf8), to: outputURL)

                return CatalogLicense(
                    title: license.name,
                    path: "\(resourcePrefix)/\(outputPath)",
                    referenceURL: componentSourceURL ?? componentHomepageURL
                )
            }

            let component = CatalogComponent(
                id: componentID,
                name: package.name,
                category: .rustCrate,
                homepageURL: componentHomepageURL,
                sourceURL: componentSourceURL,
                version: package.version,
                revision: gitRevision(from: package.source),
                attribution: package.authors.isEmpty ? nil : package.authors.joined(separator: ", "),
                notes: nil,
                licenses: licenses
            )

            componentsByID[componentID] = RustComponentAccumulator(
                component: component,
                lockfilePaths: Set([source.lockfilePath])
            )
        }
    }

    return componentsByID.values
        .map { entry in
            let component = entry.component
            let lockfileList = entry.lockfilePaths.sorted().joined(separator: " and ")
            return CatalogComponent(
                id: component.id,
                name: component.name,
                category: component.category,
                homepageURL: component.homepageURL,
                sourceURL: component.sourceURL,
                version: component.version,
                revision: component.revision,
                attribution: component.attribution,
                notes: "Generated from \(lockfileList) using cargo-about.",
                licenses: component.licenses
            )
        }
        .sorted { lhs, rhs in
            if lhs.name != rhs.name {
                return lhs.name < rhs.name
            }
            return (lhs.version ?? "") < (rhs.version ?? "")
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
            attribution: "See license text",
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
    let sourceData = try Data(contentsOf: sourceURL)
    try writeDocument(sourceData, to: destinationURL)
}

private func writeDocument(_ data: Data, to destinationURL: URL) throws {
    let fileManager = FileManager.default
    try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)

    if fileManager.fileExists(atPath: destinationURL.path) {
        let existingData = try Data(contentsOf: destinationURL)
        if existingData != data {
            throw ScriptError.conflictingGeneratedDocument(path: destinationURL.path)
        }
        return
    }

    try data.write(to: destinationURL)
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

private func packageKey(name: String, version: String) -> String {
    "\(name)@\(version)"
}

private func hasLibraryLikeTarget(_ targets: [CargoAboutSnapshot.CrateEntry.Package.Target]) -> Bool {
    targets.contains { target in
        target.kind.contains { kind in
            kind == "lib" || kind == "rlib" || kind == "staticlib" || kind == "cdylib" || kind == "dylib"
        }
    }
}

private func preferredRustSourceURL(for package: CargoAboutSnapshot.CrateEntry.Package) -> URL? {
    if let repository = package.repository, let url = URL(string: repository) {
        return url
    }

    if let source = package.source, let url = gitRepositoryURL(from: source) {
        return url
    }

    if let homepage = package.homepage, let url = URL(string: homepage) {
        return url
    }

    if let documentation = package.documentation, let url = URL(string: documentation) {
        return url
    }

    return nil
}

private func preferredRustHomepageURL(for package: CargoAboutSnapshot.CrateEntry.Package) -> URL? {
    if let homepage = package.homepage, let url = URL(string: homepage) {
        return url
    }

    if let repository = package.repository, let url = URL(string: repository) {
        return url
    }

    if let documentation = package.documentation, let url = URL(string: documentation) {
        return url
    }

    return gitRepositoryURL(from: package.source)
}

private func gitRepositoryURL(from source: String?) -> URL? {
    guard let source, source.hasPrefix("git+") else { return nil }
    let rawValue = String(source.dropFirst(4))
    let baseValue = rawValue
        .split(separator: "#", maxSplits: 1)
        .first
        .map(String.init) ?? rawValue
    let repositoryValue = baseValue
        .split(separator: "?", maxSplits: 1)
        .first
        .map(String.init) ?? baseValue
    return URL(string: repositoryValue)
}

private func gitRevision(from source: String?) -> String? {
    guard let source, source.hasPrefix("git+") else { return nil }
    let rawValue = String(source.dropFirst(4))
    guard let components = URLComponents(string: rawValue) else {
        return rawValue.split(separator: "#", maxSplits: 1).last.map(String.init)
    }

    if let revision = components.queryItems?.first(where: { $0.name == "rev" })?.value {
        return revision
    }

    return components.fragment
}

private func runCommand(_ arguments: [String], currentDirectoryURL: URL) throws {
    let process = Process()
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()

    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = arguments
    process.currentDirectoryURL = currentDirectoryURL
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stderr = String(data: stderrData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        throw ScriptError.commandFailed(
            command: arguments.joined(separator: " "),
            exitCode: process.terminationStatus,
            stderr: stderr
        )
    }
}

do {
    try run()
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
