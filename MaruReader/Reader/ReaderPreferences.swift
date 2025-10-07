//
//  ReaderPreferences.swift
//  MaruReader
//
//  Observable class for managing reader preferences and profiles.
//

import CoreData
import Foundation
import Observation
import ReadiumNavigator
import SwiftUI

@MainActor
@Observable
class ReaderPreferences {
    private(set) var book: Book
    private let context: NSManagedObjectContext

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
        }
    }

    var spread: Bool {
        get { book.spread }
        set {
            book.spread = newValue
            saveContext()
        }
    }

    var textDirection: ReadiumNavigator.ReadingProgression? {
        get { book.value(forKey: "textDirection") as? ReadiumNavigator.ReadingProgression }
        set {
            book.setValue(newValue, forKey: "textDirection")
            saveContext()
        }
    }

    var verticalText: Bool {
        get { book.verticalText }
        set {
            book.verticalText = newValue
            saveContext()
        }
    }

    // Profile-based preferences
    var fontSize: Double {
        get { profile?.fontSize ?? 100.0 }
        set {
            guard let profile else { return }
            profile.fontSize = newValue
            saveContext()
        }
    }

    var fontFamily: String? {
        get { profile?.fontFamily }
        set {
            guard let profile else { return }
            profile.fontFamily = newValue
            saveContext()
        }
    }

    var fontWeight: Double {
        get { profile?.fontWeight ?? 0.0 }
        set {
            guard let profile else { return }
            profile.fontWeight = newValue
            saveContext()
        }
    }

    var horizontalMargin: Double {
        get { profile?.horizontalMargin ?? 1.0 }
        set {
            guard let profile else { return }
            profile.horizontalMargin = newValue
            saveContext()
        }
    }

    var verticalMargin: Double {
        get { profile?.verticalMargin ?? 1.0 }
        set {
            guard let profile else { return }
            profile.verticalMargin = newValue
            saveContext()
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
    }

    private func saveContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Failed to save reader preferences: \(error)")
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
