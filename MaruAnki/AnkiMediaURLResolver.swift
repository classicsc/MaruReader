// AnkiMediaURLResolver.swift
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
import MaruReaderCore

enum AnkiMediaURLResolver {
    static func localFileURL(for url: URL) -> URL? {
        guard let scheme = url.scheme?.lowercased() else {
            return nil
        }

        switch scheme {
        case "file":
            return url
        case "marureader-audio":
            return audioFileURL(for: url)
        case "marureader-media":
            return dictionaryMediaFileURL(for: url)
        default:
            return nil
        }
    }

    static func usesInternalScheme(_ url: URL) -> Bool {
        switch url.scheme?.lowercased() {
        case "marureader-audio", "marureader-media":
            true
        default:
            false
        }
    }

    private static func audioFileURL(for url: URL) -> URL? {
        guard let host = url.host(),
              UUID(uuidString: host) != nil,
              let appGroupDir = FileManager.default.containerURL(
                  forSecurityApplicationGroupIdentifier: AnkiPersistenceController.appGroupIdentifier
              )
        else {
            return nil
        }

        let requestedPath = String(url.path.dropFirst())
        return requestedPath.split(separator: "/").reduce(
            appGroupDir
                .appendingPathComponent("AudioMedia", isDirectory: true)
                .appendingPathComponent(host, isDirectory: true)
        ) {
            $0.appendingPathComponent(String($1), isDirectory: false)
        }
    }

    private static func dictionaryMediaFileURL(for url: URL) -> URL? {
        guard let host = url.host(),
              UUID(uuidString: host) != nil,
              let appGroupDir = FileManager.default.containerURL(
                  forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
              )
        else {
            return nil
        }

        let requestedPath = String(url.path.dropFirst())
        return requestedPath.split(separator: "/").reduce(
            appGroupDir
                .appendingPathComponent("Media", isDirectory: true)
                .appendingPathComponent(host, isDirectory: true)
        ) {
            $0.appendingPathComponent(String($1), isDirectory: false)
        }
    }
}
