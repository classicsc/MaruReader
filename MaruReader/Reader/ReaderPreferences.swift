// ReaderPreferences.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import CoreData
import Foundation
import MaruReaderCore
import Observation
import os.log
import ReadiumNavigator
import SwiftUI

@MainActor
@Observable
final class ReaderPreferences {
    private(set) var book: Book
    private let context: NSManagedObjectContext
    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "ReaderPreferences")
    private var saveContextDebounceTask: Task<Void, Never>?

    weak var navigator: EPUBNavigatorViewController?

    /// Update trigger to force SwiftUI to re-render when Core Data values change
    private var updateTrigger = 0

    /// Current profile for this book
    var profile: ReaderProfile? {
        book.readerProfile
    }

    /// Check if the publication is fixed-layout (for conditional UI)
    var isFixedLayout: Bool {
        guard let navigator else { return false }
        return navigator.publication.metadata.layout == .fixed
    }

    /// Book-specific preferences
    var scroll: Bool {
        get {
            // Return actual value if set, otherwise return false (will be inferred by navigator)
            book.value(forKey: "scroll") as? Bool ?? false
        }
        set {
            book.setValue(newValue, forKey: "scroll")
            saveContext()
            submitToNavigator()
        }
    }

    var spread: Bool {
        get {
            // Return actual value if set, otherwise return false (will be inferred by navigator)
            book.value(forKey: "spread") as? Bool ?? false
        }
        set {
            book.setValue(newValue, forKey: "spread")
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
        get {
            // Return actual value if set, otherwise return false (will be inferred by navigator)
            book.value(forKey: "verticalText") as? Bool ?? false
        }
        set {
            book.setValue(newValue, forKey: "verticalText")
            saveContext()
            submitToNavigator()
        }
    }

    /// Profile-based preferences
    var fontSize: Double {
        get {
            _ = updateTrigger
            return profile?.fontSize ?? 100.0
        }
        set {
            guard let profile else { return }
            profile.fontSize = newValue
            updateTrigger += 1
            saveContext()
            submitToNavigator()
        }
    }

    var fontFamily: String? {
        get {
            _ = updateTrigger
            return profile?.fontFamily
        }
        set {
            guard let profile else { return }
            profile.fontFamily = newValue
            updateTrigger += 1
            saveContext()
            submitToNavigator()
        }
    }

    var fontWeight: Double {
        get {
            _ = updateTrigger
            return profile?.fontWeight ?? 0.0
        }
        set {
            guard let profile else { return }
            profile.fontWeight = newValue
            updateTrigger += 1
            saveContext()
            submitToNavigator()
        }
    }

    var horizontalMargin: Double {
        get {
            _ = updateTrigger
            return profile?.horizontalMargin ?? 1.0
        }
        set {
            guard let profile else { return }
            profile.horizontalMargin = newValue
            updateTrigger += 1
            saveContext()
            submitToNavigator()
        }
    }

    var verticalMargin: Double {
        get {
            _ = updateTrigger
            return profile?.verticalMargin ?? 1.0
        }
        set {
            guard let profile else { return }
            profile.verticalMargin = newValue
            updateTrigger += 1
            saveContext()
            submitToNavigator()
        }
    }

    // MARK: - Effective Values (showing what navigator actually uses)

    /// Returns the effective font size that the navigator will use
    /// If profile fontSize is 0, returns the navigator's default of 100%
    var effectiveFontSize: Double {
        let rawValue = profile?.fontSize ?? 0.0
        return rawValue != 0.0 ? rawValue : 100.0
    }

    /// Returns whether the current fontSize is using the navigator's default
    var isUsingDefaultFontSize: Bool {
        (profile?.fontSize ?? 0.0) == 0.0
    }

    /// Returns the effective horizontal margin that the navigator will use
    /// If profile horizontalMargin is 0, returns the navigator's default of 1.0
    var effectiveHorizontalMargin: Double {
        let rawValue = profile?.horizontalMargin ?? 0.0
        return rawValue != 0.0 ? rawValue : 1.0
    }

    /// Returns whether the current horizontal margin is using the navigator's default
    var isUsingDefaultHorizontalMargin: Bool {
        (profile?.horizontalMargin ?? 0.0) == 0.0
    }

    /// Returns the effective vertical margin that the navigator will use
    /// If profile verticalMargin is 0, returns the navigator's default of 1.0
    var effectiveVerticalMargin: Double {
        let rawValue = profile?.verticalMargin ?? 0.0
        return rawValue != 0.0 ? rawValue : 1.0
    }

    /// Returns whether the current vertical margin is using the navigator's default
    var isUsingDefaultVerticalMargin: Bool {
        (profile?.verticalMargin ?? 0.0) == 0.0
    }

    // MARK: - Effective Book Settings (navigator-inferred values)

    /// Returns the effective scroll mode from navigator settings if available
    /// Otherwise returns the stored value or false
    var effectiveScroll: Bool {
        navigator?.settings.scroll ?? scroll
    }

    /// Returns whether scroll is inferred by the navigator (not explicitly set by user)
    var isScrollInferred: Bool {
        book.value(forKey: "scroll") == nil
    }

    /// Returns the effective vertical text mode from navigator settings if available
    /// Otherwise returns the stored value or false
    var effectiveVerticalText: Bool {
        navigator?.settings.verticalText ?? verticalText
    }

    /// Returns whether vertical text is inferred by the navigator
    var isVerticalTextInferred: Bool {
        book.value(forKey: "verticalText") == nil
    }

    /// Returns the effective reading progression from navigator settings if available
    /// Otherwise returns the stored value or .ltr
    var effectiveReadingProgression: ReadiumNavigator.ReadingProgression {
        navigator?.settings.readingProgression ?? (textDirection ?? .ltr)
    }

    /// Returns whether reading progression is inferred by the navigator
    var isReadingProgressionInferred: Bool {
        book.value(forKey: "textDirection") == nil
    }

    /// Returns the effective spread mode from navigator settings if available
    /// Otherwise returns .auto (for fixed-layout) or based on stored value
    var effectiveSpread: Spread {
        if let navigatorSpread = navigator?.settings.spread {
            return navigatorSpread
        }
        // Fallback to stored value
        if let spreadValue = book.value(forKey: "spread") as? Bool {
            return spreadValue ? .always : .never
        }
        return .auto
    }

    /// Returns whether spread is inferred by the navigator
    var isSpreadInferred: Bool {
        book.value(forKey: "spread") == nil
    }

    /// Light theme (observable)
    var lightTheme: ReaderTheme? {
        _ = updateTrigger
        return profile?.theme
    }

    /// Dark theme (observable)
    var darkTheme: ReaderTheme? {
        _ = updateTrigger
        return profile?.darkTheme
    }

    /// Current theme (respects system dark mode if profile has both themes)
    var currentTheme: ReaderTheme? {
        _ = updateTrigger
        guard let profile else { return nil }

        // If profile has both light and dark themes, use appropriate one
        if let theme = profile.theme, let darkTheme = profile.darkTheme {
            return UITraitCollection.current.userInterfaceStyle == .dark ? darkTheme : theme
        }

        // Otherwise use the single theme
        return profile.theme
    }

    // MARK: - Interface Colors

    /// Returns the current theme's interface background color
    var currentInterfaceBackgroundColor: SwiftUI.Color? {
        _ = updateTrigger
        guard let theme = currentTheme,
              let color = theme.value(forKey: "interfaceBackgroundColor") as? ReadiumNavigator.Color
        else { return nil }
        return color.swiftUIColor
    }

    /// Returns the current theme's interface foreground color
    var currentInterfaceForegroundColor: SwiftUI.Color? {
        _ = updateTrigger
        guard let theme = currentTheme,
              let color = theme.value(forKey: "interfaceForegroundColor") as? ReadiumNavigator.Color
        else { return nil }
        return color.swiftUIColor
    }

    /// Returns the current theme's interface secondary color
    var currentInterfaceSecondaryColor: SwiftUI.Color? {
        _ = updateTrigger
        guard let theme = currentTheme,
              let color = theme.value(forKey: "interfaceSecondaryColor") as? ReadiumNavigator.Color
        else { return nil }
        return color.swiftUIColor
    }

    init(book: Book, context: NSManagedObjectContext = BookDataPersistenceController.shared.container.viewContext) {
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
        updateTrigger += 1
        saveContext()
        submitToNavigator()
    }

    // MARK: - Navigator Integration

    /// Builds EPUBPreferences from current Core Data values
    func buildEPUBPreferences() -> EPUBPreferences {
        var preferences = EPUBPreferences()

        // Book-specific settings - only set if explicitly configured by user
        // If nil, let the navigator infer from publication metadata

        if let scrollValue = book.value(forKey: "scroll") as? Bool {
            preferences.scroll = scrollValue
        }

        preferences.verticalText = false

        if let spreadValue = book.value(forKey: "spread") as? Bool {
            // Map spread: Bool -> Spread enum (.always/.never)
            preferences.spread = spreadValue ? .always : .never
        }

        // Map textDirection -> readingProgression
        if let textDirection = book.value(forKey: "textDirection") as? ReadiumNavigator.ReadingProgression {
            preferences.readingProgression = textDirection
        }

        // Profile-based settings - only set non-zero values to allow navigator defaults
        if let profile {
            // Convert fontSize from percentage (100.0 = 100%) to decimal (1.0 = 100%)
            // Only set if non-zero to allow navigator to use its default (1.0)
            if profile.fontSize != 0.0 {
                preferences.fontSize = profile.fontSize / 100.0
            }

            // Font settings
            if let fontFamily = profile.fontFamily {
                preferences.fontFamily = FontFamily(rawValue: fontFamily)
            }

            // Only set fontWeight if non-zero
            if profile.fontWeight != 0.0 {
                preferences.fontWeight = profile.fontWeight
            }

            preferences.pageMargins = 0
        }

        if UITraitCollection.current.userInterfaceStyle == .dark {
            preferences.theme = .dark
        } else {
            preferences.theme = .light
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
        saveContextDebounceTask?.cancel()
        saveContextDebounceTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            } catch {
                return // Task was cancelled
            }
            guard let self else { return }
            guard self.context.hasChanges else { return }
            do {
                try context.save()
            } catch {
                logger.error("Failed to save reader preferences: \(error)")
            }
        }
    }

    /// Helper to get all available profiles
    func fetchAllProfiles() -> [ReaderProfile] {
        let request = ReaderProfile.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ReaderProfile.isDefault, ascending: false),
            NSSortDescriptor(keyPath: \ReaderProfile.displayPriority, ascending: true),
            NSSortDescriptor(keyPath: \ReaderProfile.name, ascending: true),
        ]

        return (try? context.fetch(request)) ?? []
    }

    /// Helper to get all themes
    func fetchAllThemes() -> [ReaderTheme] {
        let request = ReaderTheme.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ReaderTheme.isSystemTheme, ascending: false),
            NSSortDescriptor(keyPath: \ReaderTheme.displayPriority, ascending: true),
            NSSortDescriptor(keyPath: \ReaderTheme.name, ascending: true),
        ]

        return (try? context.fetch(request)) ?? []
    }

    // MARK: - Theme Management

    /// Sets the light mode theme for the current profile
    func setLightTheme(_ theme: ReaderTheme?) {
        guard let profile else { return }
        profile.theme = theme
        updateTrigger += 1
        saveContext()
        submitToNavigator()
    }

    /// Sets the dark mode theme for the current profile
    func setDarkTheme(_ theme: ReaderTheme?) {
        guard let profile else { return }
        profile.darkTheme = theme
        updateTrigger += 1
        saveContext()
        submitToNavigator()
    }

    /// Increase the font size within reasonable bounds
    func increaseFontSize() {
        guard let profile else { return }
        let newSize = min(profile.fontSize + 10.0, 200.0)
        profile.fontSize = newSize
        updateTrigger += 1
        saveContext()
        submitToNavigator()
    }

    /// Decrease the font size within reasonable bounds
    func decreaseFontSize() {
        guard let profile else { return }
        let newSize = max(profile.fontSize - 10.0, 50.0)
        profile.fontSize = newSize
        updateTrigger += 1
        saveContext()
        submitToNavigator()
    }

    /// Enables or disables follow system theme mode
    /// When enabled, both light and dark themes should be set
    /// When disabled, clears the dark theme
    func setFollowSystemTheme(_ enabled: Bool) {
        guard let profile else { return }

        if !enabled {
            // Disable follow system: clear dark theme
            profile.darkTheme = nil
        } else {
            // Enable follow system: ensure both themes are set
            // If dark theme is nil, set it to the current theme or default dark theme
            if profile.darkTheme == nil {
                // Try to get the system dark theme as default
                let request = ReaderTheme.fetchRequest()
                request.predicate = NSPredicate(format: "isSystemTheme == YES AND name == %@", "Dark")
                request.fetchLimit = 1
                if let darkTheme = try? context.fetch(request).first {
                    profile.darkTheme = darkTheme
                } else {
                    profile.darkTheme = profile.theme
                }
            }
        }

        updateTrigger += 1
        saveContext()
        submitToNavigator()
    }

    /// Returns whether the profile is in follow system theme mode
    var isFollowingSystemTheme: Bool {
        _ = updateTrigger
        guard let profile else { return false }
        return profile.darkTheme != nil
    }
}
