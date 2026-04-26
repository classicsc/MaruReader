// GrammarDictionaryStorage.swift
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

public enum GrammarDictionaryStorage {
    public static let installationDirectoryName = "GrammarDictionaries"
    public static let manifestFileName = "index.json"
    public static let mediaDirectoryName = "media"

    public static func rootDirectoryURL(in baseDirectory: URL?) -> URL? {
        baseDirectory?.appendingPathComponent(installationDirectoryName, isDirectory: true)
    }

    public static func installedDirectoryURL(grammarDictionaryID: UUID, in baseDirectory: URL?) -> URL? {
        rootDirectoryURL(in: baseDirectory)?
            .appendingPathComponent(grammarDictionaryID.uuidString, isDirectory: true)
    }

    public static func manifestURL(grammarDictionaryID: UUID, in baseDirectory: URL?) -> URL? {
        installedDirectoryURL(grammarDictionaryID: grammarDictionaryID, in: baseDirectory)?
            .appendingPathComponent(manifestFileName)
    }
}
