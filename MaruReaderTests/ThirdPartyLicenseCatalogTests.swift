// ThirdPartyLicenseCatalogTests.swift
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
@testable import MaruReader
import Testing

private struct PackageResolvedForTests: Decodable {
    struct Pin: Decodable {
        let identity: String
    }

    let pins: [Pin]
}

struct ThirdPartyLicenseCatalogTests {
    private static let requiredManualIDs: Set<String> = [
        "manual-ublock-origin-lite",
        "manual-uassets-filters",
        "manual-easylist-easyprivacy",
        "manual-adguard-filters",
        "manual-material-symbols-outlined",
    ]

    @Test func catalogJSONDecodes() throws {
        let catalog = try loadCatalog()
        #expect(catalog.schemaVersion >= 1)
        #expect(!catalog.generatedAt.isEmpty)
        #expect(!catalog.components.isEmpty)
    }

    @Test func everyComponentHasAtLeastOneLicense() throws {
        let catalog = try loadCatalog()

        for component in catalog.components {
            #expect(!component.licenses.isEmpty, "Component \(component.id) has no license documents")
        }
    }

    @Test func everyLicenseDocumentPathResolves() throws {
        let catalog = try loadCatalog()

        for component in catalog.components {
            for license in component.licenses {
                let resolved = ThirdPartyLicenseCatalogLoader.documentURL(for: license.path)
                #expect(resolved != nil, "Missing bundled license file for path \(license.path)")
            }
        }
    }

    @Test func packageResolvedPinsAppearExactlyOnce() throws {
        let catalog = try loadCatalog()
        let spmIDs = catalog.components
            .filter { $0.category == .spm }
            .map(\.id)

        let expectedPinIDs = try loadResolvedPinIDs().map { "spm-\($0)" }

        let spmIDSet = Set(spmIDs)
        let expectedIDSet = Set(expectedPinIDs)

        #expect(spmIDSet == expectedIDSet)
        #expect(spmIDs.count == spmIDSet.count)
    }

    @Test func requiredManualDependenciesExist() throws {
        let catalog = try loadCatalog()
        let componentIDs = Set(catalog.components.map(\.id))

        for requiredID in Self.requiredManualIDs {
            #expect(componentIDs.contains(requiredID), "Missing required manual component: \(requiredID)")
        }
    }

    @Test func ublockEmbeddedCoverageHasBaselineEntries() throws {
        let catalog = try loadCatalog()
        let embedded = catalog.components.filter { $0.category == .ublockEmbedded }

        #expect(!embedded.isEmpty)

        let names = Set(embedded.map(\.name))
        #expect(names.contains("codemirror"))
        #expect(names.contains("js-beautify"))
    }

    private func loadCatalog() throws -> ThirdPartyLicenseCatalog {
        try ThirdPartyLicenseCatalogLoader.loadCatalog()
    }

    private func loadResolvedPinIDs() throws -> [String] {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let resolvedURL = rootURL
            .appendingPathComponent("MaruReader.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved")

        let data = try Data(contentsOf: resolvedURL)
        let resolved = try JSONDecoder().decode(PackageResolvedForTests.self, from: data)
        return resolved.pins.map(\.identity)
    }
}
