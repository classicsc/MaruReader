// MangaMetadataExtractionSettings.swift
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

public enum MangaMetadataExtractionSettings {
    public static let smartExtractionEnabledKey = "mangaSmartMetadataExtractionEnabled"
    public static let smartExtractionEnabledDefault = true
    static let screenshotModeArgument = "--screenshotMode"

    public static var smartExtractionEnabled: Bool {
        get {
            let storedValue = UserDefaults.standard.object(forKey: smartExtractionEnabledKey) as? Bool
            return resolvedSmartExtractionEnabled(
                storedValue: storedValue,
                processArguments: ProcessInfo.processInfo.arguments
            )
        }
        set {
            UserDefaults.standard.set(newValue, forKey: smartExtractionEnabledKey)
        }
    }

    static func resolvedSmartExtractionEnabled(
        storedValue: Bool?,
        processArguments: [String]
    ) -> Bool {
        guard !processArguments.contains(screenshotModeArgument) else {
            return false
        }
        return storedValue ?? smartExtractionEnabledDefault
    }
}
