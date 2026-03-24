// ReaderAppearancePreferences.swift
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
import SwiftUI

enum ReaderFontFamilyOption: String, CaseIterable {
    case mincho
    case gothic

    var displayName: String {
        switch self {
        case .mincho:
            String(localized: "Mincho")
        case .gothic:
            String(localized: "Gothic")
        }
    }

    var fontFamilyStack: String {
        switch self {
        case .mincho:
            "Hiragino Mincho ProN"
        case .gothic:
            "Hiragino Kaku Gothic ProN"
        }
    }
}

enum ReaderAppearanceMode: String, CaseIterable {
    case followSystem
    case light
    case dark
    case sepia

    var displayName: String {
        switch self {
        case .followSystem:
            String(localized: "Follow System")
        case .light:
            String(localized: "Light")
        case .dark:
            String(localized: "Dark")
        case .sepia:
            String(localized: "Sepia")
        }
    }
}

enum ReaderAppearancePreferences {
    static let fontScaleKey = "readerAppearance.fontScale"
    static let fontFamilyOptionKey = "readerAppearance.fontFamilyOption"
    static let appearanceModeKey = "readerAppearance.appearanceMode"

    static let fontScaleDefault = 150.0
    static let fontFamilyOptionDefault = ReaderFontFamilyOption.mincho
    static let appearanceModeDefault = ReaderAppearanceMode.followSystem

    static let allKeys = [
        fontScaleKey,
        fontFamilyOptionKey,
        appearanceModeKey,
    ]

    static var fontScale: Double {
        get {
            let storedValue = UserDefaults.standard.object(forKey: fontScaleKey) as? Double
            return storedValue ?? fontScaleDefault
        }
        set {
            UserDefaults.standard.set(newValue, forKey: fontScaleKey)
        }
    }

    static var fontFamilyOption: ReaderFontFamilyOption {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: fontFamilyOptionKey),
                  let option = ReaderFontFamilyOption(rawValue: rawValue)
            else {
                return fontFamilyOptionDefault
            }
            return option
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: fontFamilyOptionKey)
        }
    }

    static var hasStoredFontFamilyOption: Bool {
        UserDefaults.standard.object(forKey: fontFamilyOptionKey) != nil
    }

    static var appearanceMode: ReaderAppearanceMode {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: appearanceModeKey),
                  let mode = ReaderAppearanceMode(rawValue: rawValue)
            else {
                return appearanceModeDefault
            }
            return mode
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: appearanceModeKey)
        }
    }
}

struct ReaderAppearanceTheme {
    let pageBackgroundColor: Color
    let interfaceBackgroundColor: Color
    let interfaceForegroundColor: Color
    let interfaceSecondaryColor: Color
}

enum ReaderAppearanceThemeCatalog {
    static let navigatorHorizontalInset = 40.0

    static func resolvedTheme(
        for mode: ReaderAppearanceMode,
        systemColorScheme: ColorScheme
    ) -> ReaderAppearanceTheme {
        switch mode {
        case .followSystem:
            systemColorScheme == .dark ? darkTheme : lightTheme
        case .light:
            lightTheme
        case .dark:
            darkTheme
        case .sepia:
            sepiaTheme
        }
    }

    private static let lightTheme = ReaderAppearanceTheme(
        pageBackgroundColor: .white,
        interfaceBackgroundColor: .white,
        interfaceForegroundColor: .black,
        interfaceSecondaryColor: color(red: 108, green: 108, blue: 112)
    )

    private static let darkTheme = ReaderAppearanceTheme(
        pageBackgroundColor: .black,
        interfaceBackgroundColor: .black,
        interfaceForegroundColor: .white,
        interfaceSecondaryColor: color(red: 152, green: 152, blue: 157)
    )

    private static let sepiaTheme = ReaderAppearanceTheme(
        pageBackgroundColor: color(red: 249, green: 244, blue: 233),
        interfaceBackgroundColor: color(red: 245, green: 237, blue: 214),
        interfaceForegroundColor: color(red: 92, green: 74, blue: 47),
        interfaceSecondaryColor: color(red: 139, green: 115, blue: 85)
    )

    private static func color(red: Double, green: Double, blue: Double) -> Color {
        Color(red: red / 255.0, green: green / 255.0, blue: blue / 255.0)
    }
}
