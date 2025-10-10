//
//  ReaderPreferences.swift
//  MaruReader
//
//  Observable class for managing reader preferences and profiles.
//

import CoreData
import Foundation
import Observation
import os.log
import ReadiumNavigator
import SwiftUI

@MainActor
@Observable
class ReaderPreferences {
    private(set) var book: Book
    private let context: NSManagedObjectContext
    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "ReaderPreferences")

    weak var navigator: EPUBNavigatorViewController?

    // Current profile for this book
    var profile: ReaderProfile? {
        book.readerProfile
    }

    // Book-specific preferences
    var scroll: Bool {
        get { book.scroll }
        set {
            book.scroll = newValue
            saveContext()
            submitToNavigator()
        }
    }

    var spread: Bool {
        get { book.spread }
        set {
            book.spread = newValue
            saveContext()
            submitToNavigator()
        }
    }

    var textDirection: ReadiumNavigator.ReadingProgression? {
        get { book.value(forKey: "textDirection") as? ReadiumNavigator.ReadingProgression }
        set {
            book.setValue(newValue, forKey: "textDirection")
            saveContext()
            submitToNavigator()
        }
    }

    var verticalText: Bool {
        get { book.verticalText }
        set {
            book.verticalText = newValue
            saveContext()
            submitToNavigator()
        }
    }

    // Profile-based preferences
    var fontSize: Double {
        get { profile?.fontSize ?? 100.0 }
        set {
            guard let profile else { return }
            profile.fontSize = newValue
            saveContext()
            submitToNavigator()
        }
    }

    var fontFamily: String? {
        get { profile?.fontFamily }
        set {
            guard let profile else { return }
            profile.fontFamily = newValue
            saveContext()
            submitToNavigator()
        }
    }

    var fontWeight: Double {
        get { profile?.fontWeight ?? 0.0 }
        set {
            guard let profile else { return }
            profile.fontWeight = newValue
            saveContext()
            submitToNavigator()
        }
    }

    var horizontalMargin: Double {
        get { profile?.horizontalMargin ?? 1.0 }
        set {
            guard let profile else { return }
            profile.horizontalMargin = newValue
            saveContext()
            submitToNavigator()
        }
    }

    var verticalMargin: Double {
        get { profile?.verticalMargin ?? 1.0 }
        set {
            guard let profile else { return }
            profile.verticalMargin = newValue
            saveContext()
            submitToNavigator()
        }
    }

    // Current theme (respects system dark mode if profile has both themes)
    var currentTheme: ReaderTheme? {
        guard let profile else { return nil }

        // If profile has both light and dark themes, use appropriate one
        if let theme = profile.theme, let darkTheme = profile.darkTheme {
            return UITraitCollection.current.userInterfaceStyle == .dark ? darkTheme : theme
        }

        // Otherwise use the single theme
        return profile.theme
    }

    init(book: Book, context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.book = book
        self.context = context

        // Ensure book has a profile
        if book.readerProfile == nil {
            let themeManager = SystemThemeManager()
            themeManager.ensureSystemThemesExist()
            book.readerProfile = themeManager.getProfile(for: book)
        }
    }

    func setProfile(_ profile: ReaderProfile) {
        book.readerProfile = profile
        saveContext()
        submitToNavigator()
    }

    // MARK: - Navigator Integration

    /// Builds EPUBPreferences from current Core Data values
    func buildEPUBPreferences() -> EPUBPreferences {
        var preferences = EPUBPreferences()

        // Book-specific settings
        preferences.scroll = book.scroll
        preferences.verticalText = book.verticalText

        // Map spread: Bool -> Spread enum (.always/.never)
        if book.spread {
            preferences.spread = .always
        } else {
            preferences.spread = .never
        }

        // Map textDirection -> readingProgression
        if let textDirection = book.value(forKey: "textDirection") as? ReadiumNavigator.ReadingProgression {
            preferences.readingProgression = textDirection
        }

        // Profile-based settings
        if let profile {
            // Convert fontSize from percentage (100.0 = 100%) to decimal (1.0 = 100%)
            preferences.fontSize = profile.fontSize / 100.0

            // Font settings
            if let fontFamily = profile.fontFamily {
                preferences.fontFamily = FontFamily(rawValue: fontFamily)
            }
            preferences.fontWeight = profile.fontWeight

            // Margins (use horizontalMargin as pageMargins since EPUBPreferences has a single value)
            preferences.pageMargins = profile.horizontalMargin

            // Theme-based settings
            if let theme = currentTheme {
                if let bgColor = theme.value(forKey: "backgroundColor") as? ReadiumNavigator.Color {
                    preferences.backgroundColor = bgColor
                }
                if let textColor = theme.value(forKey: "textColor") as? ReadiumNavigator.Color {
                    preferences.textColor = textColor
                }
                if let imageFilter = theme.value(forKey: "imageFilter") as? ImageFilter {
                    preferences.imageFilter = imageFilter
                }
            }
        }

        return preferences
    }

    /// Submits current preferences to the navigator
    func submitToNavigator() {
        guard let navigator else {
            logger.debug("Navigator not available, skipping preference submission")
            return
        }

        let preferences = buildEPUBPreferences()
        navigator.submitPreferences(preferences)
        logger.debug("Submitted preferences to navigator")
    }

    private func saveContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            logger.error("Failed to save reader preferences: \(error)")
        }
    }

    // Helper to get all available profiles
    func fetchAllProfiles() -> [ReaderProfile] {
        let request = ReaderProfile.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ReaderProfile.isDefault, ascending: false),
            NSSortDescriptor(keyPath: \ReaderProfile.displayPriority, ascending: true),
            NSSortDescriptor(keyPath: \ReaderProfile.name, ascending: true),
        ]

        return (try? context.fetch(request)) ?? []
    }

    // Helper to get all themes
    func fetchAllThemes() -> [ReaderTheme] {
        let request = ReaderTheme.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ReaderTheme.isSystemTheme, ascending: false),
            NSSortDescriptor(keyPath: \ReaderTheme.displayPriority, ascending: true),
            NSSortDescriptor(keyPath: \ReaderTheme.name, ascending: true),
        ]

        return (try? context.fetch(request)) ?? []
    }
}
