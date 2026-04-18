// TokenizerDictionaryStorage.swift
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

public enum TokenizerDictionaryStorage {
    public static let installationDirectoryName = "TokenizerDictionary"
    public static let manifestFileName = "index.json"
    public static let requiredResourceFiles = [
        "char.def",
        "rewrite.def",
        "sudachi.json",
        "system_full.dic",
        "unk.def",
    ]

    public static func installedDirectoryURL(in baseDirectory: URL?) -> URL? {
        baseDirectory?.appendingPathComponent(installationDirectoryName, isDirectory: true)
    }

    public static func installedDirectoryURL() -> URL? {
        let baseDirectory = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
        )
        return installedDirectoryURL(in: baseDirectory)
    }

    public static func manifestURL(in baseDirectory: URL?) -> URL? {
        installedDirectoryURL(in: baseDirectory)?.appendingPathComponent(manifestFileName)
    }
}
