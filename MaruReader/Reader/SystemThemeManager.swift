// SystemThemeManager.swift
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
import MaruReaderCore
import ReadiumNavigator
import SwiftUI

@MainActor
struct SystemThemeManager {
    private let context: NSManagedObjectContext = BookDataPersistenceController.shared.container.viewContext

    // Stable IDs for system themes
    private let lightThemeID = UUID(uuidString: "E4D81462-B651-43E3-A670-79A13C0B9A65")!
    private let darkThemeID = UUID(uuidString: "AE912579-49EF-49E7-BFB4-7C228A932E14")!
    private let sepiaThemeID = UUID(uuidString: "31A30AB8-0382-4C50-B982-9E2D8BA61A39")!

    /// Creates default system themes if they don't exist
    func ensureSystemThemesExist() {
        let request = ReaderTheme.fetchRequest()
        request.predicate = NSPredicate(format: "isSystemTheme == YES")

        guard let existingThemes = try? context.fetch(request) else { return }

        let existingThemeIDs = Set(existingThemes.compactMap(\.id))

        // Create Light theme if missing
        if !existingThemeIDs.contains(lightThemeID) {
            createLightTheme()
        }

        // Create Dark theme if missing
        if !existingThemeIDs.contains(sepiaThemeID) {
            createDarkTheme()
        }

        // Create Sepia theme if missing
        if !existingThemeIDs.contains(darkThemeID) {
            createSepiaTheme()
        }

        // Save if any themes were created
        if context.hasChanges {
            try? context.save()
        }
    }

    private func createLightTheme() {
        let theme = ReaderTheme(context: context)
        theme.id = lightThemeID
        theme.name = "Light"
        theme.isSystemTheme = true
        theme.displayPriority = 0

        // Readium defaults for light mode
        theme.setValue(ReadiumNavigator.Color(hex: "#FFFFFF"), forKey: "backgroundColor")
        theme.setValue(ReadiumNavigator.Color(hex: "#121212"), forKey: "textColor")

        // Interface colors for SwiftUI components
        theme.setValue(ReadiumNavigator.Color(hex: "#FFFFFF"), forKey: "interfaceBackgroundColor")
        theme.setValue(ReadiumNavigator.Color(hex: "#000000"), forKey: "interfaceForegroundColor")
        theme.setValue(ReadiumNavigator.Color(hex: "#6C6C70"), forKey: "interfaceSecondaryColor")

        // Icon colors
        theme.setValue(ReadiumNavigator.Color(hex: "#FFFFFF"), forKey: "iconColor")
        theme.setValue(ReadiumNavigator.Color(hex: "#000000"), forKey: "iconTextColor")

        // Highlight color
        theme.setValue(ReadiumNavigator.Color(hex: "#FFFF00"), forKey: "highlightColor")
    }

    private func createDarkTheme() {
        let theme = ReaderTheme(context: context)
        theme.id = darkThemeID
        theme.name = "Dark"
        theme.isSystemTheme = true
        theme.displayPriority = 1

        // Readium defaults for dark mode
        theme.setValue(ReadiumNavigator.Color(hex: "#000000"), forKey: "backgroundColor")
        theme.setValue(ReadiumNavigator.Color(hex: "#FEFEFE"), forKey: "textColor")

        // Interface colors for SwiftUI components
        theme.setValue(ReadiumNavigator.Color(hex: "#000000"), forKey: "interfaceBackgroundColor")
        theme.setValue(ReadiumNavigator.Color(hex: "#FFFFFF"), forKey: "interfaceForegroundColor")
        theme.setValue(ReadiumNavigator.Color(hex: "#98989D"), forKey: "interfaceSecondaryColor")

        // Icon colors
        theme.setValue(ReadiumNavigator.Color(hex: "#1C1C1E"), forKey: "iconColor")
        theme.setValue(ReadiumNavigator.Color(hex: "#FFFFFF"), forKey: "iconTextColor")

        // Highlight color
        theme.setValue(ReadiumNavigator.Color(hex: "#FFD700"), forKey: "highlightColor")

        // Image filter for dark mode
        theme.setValue(ReadiumNavigator.ImageFilter.darken, forKey: "imageFilter")
    }

    private func createSepiaTheme() {
        let theme = ReaderTheme(context: context)
        theme.id = sepiaThemeID
        theme.name = "Sepia"
        theme.isSystemTheme = true
        theme.displayPriority = 2

        // Readium defaults for sepia mode
        theme.setValue(ReadiumNavigator.Color(hex: "#faf4e8"), forKey: "backgroundColor")
        theme.setValue(ReadiumNavigator.Color(hex: "#121212"), forKey: "textColor")

        // Interface colors for SwiftUI components
        theme.setValue(ReadiumNavigator.Color(hex: "#F5EDD6"), forKey: "interfaceBackgroundColor")
        theme.setValue(ReadiumNavigator.Color(hex: "#5C4A2F"), forKey: "interfaceForegroundColor")
        theme.setValue(ReadiumNavigator.Color(hex: "#8B7355"), forKey: "interfaceSecondaryColor")

        // Icon colors
        theme.setValue(ReadiumNavigator.Color(hex: "#F5EDD6"), forKey: "iconColor")
        theme.setValue(ReadiumNavigator.Color(hex: "#5C4A2F"), forKey: "iconTextColor")

        // Highlight color
        theme.setValue(ReadiumNavigator.Color(hex: "#FFE4B5"), forKey: "highlightColor")
    }

    /// Fetches the default profile for the book's language, or creates one if none exists
    func getProfile(for book: Book) -> ReaderProfile {
        let language = book.language ?? "und" // "und" = undefined
        let request = ReaderProfile.fetchRequest()
        request.predicate = NSPredicate(format: "language == %@", language)
        request.fetchLimit = 1
        if let profile = try? context.fetch(request).first {
            return profile
        } else {
            return createDefaultProfile(for: language)
        }
    }

    private func createDefaultProfile(for language: String) -> ReaderProfile {
        let profile = ReaderProfile(context: context)
        profile.id = UUID()
        profile.name = "Default"
        profile.isDefault = true
        profile.displayPriority = 0
        profile.language = language
        profile.horizontalMargin = 40.0
        profile.verticalMargin = 20.0

        // Most attributes not set to allow fallback to publication defaults

        // Default icon
        profile.iconCharacter = "A"

        // Link to light and dark themes
        if let lightTheme = fetchSystemTheme(with: lightThemeID) {
            profile.theme = lightTheme
        }

        if let darkTheme = fetchSystemTheme(with: darkThemeID) {
            profile.darkTheme = darkTheme
        }

        // Save the profile
        try? context.save()

        return profile
    }

    private func fetchSystemTheme(with id: UUID) -> ReaderTheme? {
        let request = ReaderTheme.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND isSystemTheme == YES", id as CVarArg)
        request.fetchLimit = 1

        return try? context.fetch(request).first
    }
}
