// DictionaryDisplayPreferences.swift
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

public enum DictionaryDisplayPreferences {
    public static let fontFamilyKey = "dictionaryDisplay.fontFamily"
    public static let fontSizeKey = "dictionaryDisplay.fontSize"
    public static let popupFontSizeKey = "dictionaryDisplay.popupFontSize"
    public static let pitchDownstepNotationInHeaderEnabledKey = "dictionaryDisplay.pitchDownstepNotationInHeaderEnabled"
    public static let pitchResultsAreaCollapsedDisplayKey = "dictionaryDisplay.pitchResultsAreaCollapsedDisplay"
    public static let pitchResultsAreaDownstepNotationEnabledKey = "dictionaryDisplay.pitchResultsAreaDownstepNotationEnabled"
    public static let pitchResultsAreaDownstepPositionEnabledKey = "dictionaryDisplay.pitchResultsAreaDownstepPositionEnabled"
    public static let pitchResultsAreaEnabledKey = "dictionaryDisplay.pitchResultsAreaEnabled"
    public static let contextFontSizeKey = "dictionaryDisplay.contextFontSize"
    public static let contextFuriganaEnabledKey = "dictionaryDisplay.contextFuriganaEnabled"

    public static let fontFamilyDefault = DictionaryDisplayDefaults.defaultFontFamily
    public static let fontSizeDefault = DictionaryDisplayDefaults.defaultFontSize
    public static let popupFontSizeDefault = DictionaryDisplayDefaults.defaultPopupFontSize
    public static let pitchDownstepNotationInHeaderEnabledDefault = DictionaryDisplayDefaults.defaultPitchDownstepNotationInHeaderEnabled
    public static let pitchResultsAreaCollapsedDisplayDefault = DictionaryDisplayDefaults.defaultPitchResultsAreaCollapsedDisplay
    public static let pitchResultsAreaDownstepNotationEnabledDefault = DictionaryDisplayDefaults.defaultPitchResultsAreaDownstepNotationEnabled
    public static let pitchResultsAreaDownstepPositionEnabledDefault = DictionaryDisplayDefaults.defaultPitchResultsAreaDownstepPositionEnabled
    public static let pitchResultsAreaEnabledDefault = DictionaryDisplayDefaults.defaultPitchResultsAreaEnabled
    public static let contextFontSizeDefault = DictionaryDisplayDefaults.defaultContextFontSize
    public static let contextFuriganaEnabledDefault = DictionaryDisplayDefaults.defaultContextFuriganaEnabled

    static let allKeys = [
        fontFamilyKey,
        fontSizeKey,
        popupFontSizeKey,
        pitchDownstepNotationInHeaderEnabledKey,
        pitchResultsAreaCollapsedDisplayKey,
        pitchResultsAreaDownstepNotationEnabledKey,
        pitchResultsAreaDownstepPositionEnabledKey,
        pitchResultsAreaEnabledKey,
        contextFontSizeKey,
        contextFuriganaEnabledKey,
    ]

    public static var fontFamily: String {
        get {
            guard let stored = UserDefaults.standard.string(forKey: fontFamilyKey) else {
                return fontFamilyDefault
            }

            let normalized = DictionaryDisplayFontFamilyStacks.normalize(stored)
            if normalized != stored {
                UserDefaults.standard.set(normalized, forKey: fontFamilyKey)
            }
            return normalized
        }
        set {
            UserDefaults.standard.set(DictionaryDisplayFontFamilyStacks.normalize(newValue), forKey: fontFamilyKey)
        }
    }

    public static var fontSize: Double {
        get {
            let stored = UserDefaults.standard.object(forKey: fontSizeKey) as? Double
            return stored ?? fontSizeDefault
        }
        set {
            UserDefaults.standard.set(newValue, forKey: fontSizeKey)
        }
    }

    public static var popupFontSize: Double {
        get {
            let stored = UserDefaults.standard.object(forKey: popupFontSizeKey) as? Double
            return stored ?? popupFontSizeDefault
        }
        set {
            UserDefaults.standard.set(newValue, forKey: popupFontSizeKey)
        }
    }

    public static var pitchDownstepNotationInHeaderEnabled: Bool {
        get {
            let stored = UserDefaults.standard.object(forKey: pitchDownstepNotationInHeaderEnabledKey) as? Bool
            return stored ?? pitchDownstepNotationInHeaderEnabledDefault
        }
        set {
            UserDefaults.standard.set(newValue, forKey: pitchDownstepNotationInHeaderEnabledKey)
        }
    }

    public static var pitchResultsAreaCollapsedDisplay: Bool {
        get {
            let stored = UserDefaults.standard.object(forKey: pitchResultsAreaCollapsedDisplayKey) as? Bool
            return stored ?? pitchResultsAreaCollapsedDisplayDefault
        }
        set {
            UserDefaults.standard.set(newValue, forKey: pitchResultsAreaCollapsedDisplayKey)
        }
    }

    public static var pitchResultsAreaDownstepNotationEnabled: Bool {
        get {
            let stored = UserDefaults.standard.object(forKey: pitchResultsAreaDownstepNotationEnabledKey) as? Bool
            return stored ?? pitchResultsAreaDownstepNotationEnabledDefault
        }
        set {
            UserDefaults.standard.set(newValue, forKey: pitchResultsAreaDownstepNotationEnabledKey)
        }
    }

    public static var pitchResultsAreaDownstepPositionEnabled: Bool {
        get {
            let stored = UserDefaults.standard.object(forKey: pitchResultsAreaDownstepPositionEnabledKey) as? Bool
            return stored ?? pitchResultsAreaDownstepPositionEnabledDefault
        }
        set {
            UserDefaults.standard.set(newValue, forKey: pitchResultsAreaDownstepPositionEnabledKey)
        }
    }

    public static var pitchResultsAreaEnabled: Bool {
        get {
            let stored = UserDefaults.standard.object(forKey: pitchResultsAreaEnabledKey) as? Bool
            return stored ?? pitchResultsAreaEnabledDefault
        }
        set {
            UserDefaults.standard.set(newValue, forKey: pitchResultsAreaEnabledKey)
        }
    }

    public static var contextFontSize: Double {
        get {
            let stored = UserDefaults.standard.object(forKey: contextFontSizeKey) as? Double
            return stored ?? contextFontSizeDefault
        }
        set {
            UserDefaults.standard.set(newValue, forKey: contextFontSizeKey)
        }
    }

    public static var contextFuriganaEnabled: Bool {
        get {
            let stored = UserDefaults.standard.object(forKey: contextFuriganaEnabledKey) as? Bool
            return stored ?? contextFuriganaEnabledDefault
        }
        set {
            UserDefaults.standard.set(newValue, forKey: contextFuriganaEnabledKey)
        }
    }

    public static var displayStyles: DisplayStyles {
        DisplayStyles(
            fontFamily: fontFamily,
            contentFontSize: fontSize,
            popupFontSize: popupFontSize,
            pitchDownstepNotationInHeaderEnabled: pitchDownstepNotationInHeaderEnabled,
            pitchResultsAreaCollapsedDisplay: pitchResultsAreaCollapsedDisplay,
            pitchResultsAreaDownstepNotationEnabled: pitchResultsAreaDownstepNotationEnabled,
            pitchResultsAreaDownstepPositionEnabled: pitchResultsAreaDownstepPositionEnabled,
            pitchResultsAreaEnabled: pitchResultsAreaEnabled
        )
    }
}
