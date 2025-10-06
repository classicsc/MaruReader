//
//  SystemThemeManager.swift
//  MaruReader
//
//  Manages system-defined reader themes and ensures they exist at app launch.
//

import CoreData
import Foundation
import ReadiumNavigator
import SwiftUI

@MainActor
class SystemThemeManager {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    /// Creates default system themes if they don't exist
    func ensureSystemThemesExist() {
        let request = ReaderTheme.fetchRequest()
        request.predicate = NSPredicate(format: "isSystemTheme == YES")

        guard let existingThemes = try? context.fetch(request) else { return }

        let existingThemeNames = Set(existingThemes.compactMap(\.name))

        // Create Light theme if missing
        if !existingThemeNames.contains("Light") {
            createLightTheme()
        }

        // Create Dark theme if missing
        if !existingThemeNames.contains("Dark") {
            createDarkTheme()
        }

        // Create Sepia theme if missing
        if !existingThemeNames.contains("Sepia") {
            createSepiaTheme()
        }

        // Save if any themes were created
        if context.hasChanges {
            try? context.save()
        }
    }

    private func createLightTheme() {
        let theme = ReaderTheme(context: context)
        theme.id = UUID()
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
        theme.id = UUID()
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
        theme.id = UUID()
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

    /// Creates a default reader profile for a book using system defaults
    func createDefaultProfile(for _: Book) -> ReaderProfile {
        let profile = ReaderProfile(context: context)
        profile.id = UUID()
        profile.name = "Default"
        profile.isDefault = true
        profile.displayPriority = 0

        // Set Readium default font settings (will be nil = use publication defaults)
        profile.fontFamily = nil
        profile.fontSize = 100.0 // 100% is the Readium default
        profile.fontWeight = 0.0 // 0.0 means use default
        profile.horizontalMargin = 1.0 // Readium default
        profile.verticalMargin = 1.0 // Readium default

        // Default icon
        profile.iconCharacter = "A"

        // Link to light theme by default
        if let lightTheme = fetchSystemTheme(named: "Light") {
            profile.theme = lightTheme
        }

        // Save the profile
        try? context.save()

        return profile
    }

    private func fetchSystemTheme(named name: String) -> ReaderTheme? {
        let request = ReaderTheme.fetchRequest()
        request.predicate = NSPredicate(format: "isSystemTheme == YES AND name == %@", name)
        request.fetchLimit = 1

        return try? context.fetch(request).first
    }
}
