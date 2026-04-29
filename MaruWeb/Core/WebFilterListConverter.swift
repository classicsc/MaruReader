// WebFilterListConverter.swift
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

import CryptoKit
import Foundation

public enum WebFilterListFormat: Sendable, Equatable {
    case standard
    case hosts

    fileprivate var ffiValue: AdblockFilterListFormat {
        switch self {
        case .standard:
            .standard
        case .hosts:
            .hosts
        }
    }
}

public enum WebFilterRuleTypes: Sendable, Equatable {
    case all
    case networkOnly
    case cosmeticOnly

    fileprivate var ffiValue: AdblockFilterRuleTypes {
        switch self {
        case .all:
            .all
        case .networkOnly:
            .networkOnly
        case .cosmeticOnly:
            .cosmeticOnly
        }
    }
}

public struct WebFilterListSource: Sendable, Equatable {
    public let identifier: String
    public let contents: String
    public let format: WebFilterListFormat
    public let permissionMask: UInt8

    public init(
        identifier: String,
        contents: String,
        format: WebFilterListFormat = .standard,
        permissionMask: UInt8 = 0
    ) {
        self.identifier = identifier
        self.contents = contents
        self.format = format
        self.permissionMask = permissionMask
    }

    var ffiValue: AdblockFilterListInput {
        AdblockFilterListInput(
            identifier: identifier,
            contents: contents,
            format: format.ffiValue,
            permissionMask: permissionMask
        )
    }
}

public struct WebFilterListConversionOptions: Sendable, Equatable {
    public let identifierPrefix: String
    public let ruleTypes: WebFilterRuleTypes

    public init(
        identifierPrefix: String = "maruweb-adblock",
        ruleTypes: WebFilterRuleTypes = .all
    ) {
        self.identifierPrefix = identifierPrefix
        self.ruleTypes = ruleTypes
    }

    fileprivate var ffiValue: AdblockConversionOptions {
        AdblockConversionOptions(ruleTypes: ruleTypes.ffiValue)
    }
}

public struct WebContentRuleListDefinition: Sendable, Equatable {
    public let identifier: String
    public let encodedContentRuleList: String
    public let ruleCount: Int
    public let convertedFilterCount: Int
    public let contentDigest: String

    public init(
        identifier: String,
        encodedContentRuleList: String,
        ruleCount: Int,
        convertedFilterCount: Int,
        contentDigest: String
    ) {
        self.identifier = identifier
        self.encodedContentRuleList = encodedContentRuleList
        self.ruleCount = ruleCount
        self.convertedFilterCount = convertedFilterCount
        self.contentDigest = contentDigest
    }
}

public enum WebFilterListConverter {
    public static func convert(
        _ filterLists: [WebFilterListSource],
        options: WebFilterListConversionOptions = WebFilterListConversionOptions()
    ) throws -> WebContentRuleListDefinition {
        let result = try convertFilterListsToContentRuleListJson(
            filterLists: filterLists.map(\.ffiValue),
            options: options.ffiValue
        )
        let digest = contentDigest(for: result.contentRuleListJson)
        let identifier = "\(options.identifierPrefix)-\(digest.prefix(32))"

        return WebContentRuleListDefinition(
            identifier: identifier,
            encodedContentRuleList: result.contentRuleListJson,
            ruleCount: Int(result.contentRuleCount),
            convertedFilterCount: Int(result.convertedFilterCount),
            contentDigest: digest
        )
    }

    private static func contentDigest(for contentRuleListJSON: String) -> String {
        let data = Data(contentRuleListJSON.utf8)
        let hexDigits = Array("0123456789abcdef".utf8)
        var bytes: [UInt8] = []
        bytes.reserveCapacity(SHA256.byteCount * 2)

        for byte in SHA256.hash(data: data) {
            bytes.append(hexDigits[Int(byte >> 4)])
            bytes.append(hexDigits[Int(byte & 0x0F)])
        }

        return String(decoding: bytes, as: UTF8.self)
    }
}
