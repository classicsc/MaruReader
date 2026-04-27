// WebFilterListEntry.swift
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

import CoreData
import Foundation

/// Sendable, value-type snapshot of a `WebFilterList` Core Data row. Storage and consumers
/// always hand around `WebFilterListEntry` values across actor boundaries; managed objects
/// stay confined to the storage's view context.
public struct WebFilterListEntry: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let sourceURL: URL
    public let name: String
    public let format: WebFilterListFormat
    public let isEnabled: Bool
    public let sortOrder: Int
    public let addedAt: Date
    public let lastFetchAttemptAt: Date?
    public let lastFetchSuccessAt: Date?
    public let lastFetchError: String?
    public let etag: String?
    public let lastModifiedHeader: String?
    public let contentDigest: String?
    public let ruleCount: Int
    public let convertedFilterCount: Int

    public init(
        id: UUID,
        sourceURL: URL,
        name: String,
        format: WebFilterListFormat,
        isEnabled: Bool,
        sortOrder: Int,
        addedAt: Date,
        lastFetchAttemptAt: Date?,
        lastFetchSuccessAt: Date?,
        lastFetchError: String?,
        etag: String?,
        lastModifiedHeader: String?,
        contentDigest: String?,
        ruleCount: Int,
        convertedFilterCount: Int
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.name = name
        self.format = format
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.addedAt = addedAt
        self.lastFetchAttemptAt = lastFetchAttemptAt
        self.lastFetchSuccessAt = lastFetchSuccessAt
        self.lastFetchError = lastFetchError
        self.etag = etag
        self.lastModifiedHeader = lastModifiedHeader
        self.contentDigest = contentDigest
        self.ruleCount = ruleCount
        self.convertedFilterCount = convertedFilterCount
    }
}

extension WebFilterListEntry {
    init?(_ managed: WebFilterList) {
        guard
            let id = managed.id,
            let urlString = managed.sourceURL,
            let url = URL(string: urlString),
            let addedAt = managed.addedAt
        else { return nil }
        self.init(
            id: id,
            sourceURL: url,
            name: managed.name ?? url.lastPathComponent,
            format: WebFilterListFormat(rawValue: managed.formatRaw ?? "") ?? .standard,
            isEnabled: managed.isEnabled,
            sortOrder: Int(managed.sortOrder),
            addedAt: addedAt,
            lastFetchAttemptAt: managed.lastFetchAttemptAt,
            lastFetchSuccessAt: managed.lastFetchSuccessAt,
            lastFetchError: managed.lastFetchError,
            etag: managed.etag,
            lastModifiedHeader: managed.lastModifiedHeader,
            contentDigest: managed.contentDigest,
            ruleCount: Int(managed.ruleCount),
            convertedFilterCount: Int(managed.convertedFilterCount)
        )
    }
}

extension WebFilterListFormat: RawRepresentable {
    public init?(rawValue: String) {
        switch rawValue {
        case "standard": self = .standard
        case "hosts": self = .hosts
        default: return nil
        }
    }

    public var rawValue: String {
        switch self {
        case .standard: "standard"
        case .hosts: "hosts"
        }
    }
}
