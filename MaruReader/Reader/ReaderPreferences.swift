// ReaderPreferences.swift
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
import Observation
import os
import ReadiumNavigator
import SwiftUI

@MainActor
@Observable
final class ReaderPreferences {
    private let bookID: NSManagedObjectID
    private let context: NSManagedObjectContext
    private let logger = Logger.maru(category: "ReaderPreferences")
    private var saveContextDebounceTask: Task<Void, Never>?
    private var appearanceUpdateTrigger = 0

    @ObservationIgnored
    weak var navigator: EPUBNavigatorViewController?
    var systemColorScheme: ColorScheme = .light

    /// Check if the publication is fixed-layout (for conditional UI)
    var isFixedLayout: Bool {
        guard let navigator else { return false }
        return navigator.publication.metadata.layout == .fixed
    }

    /// Book-specific preferences
    var scroll: Bool {
        get {
            bookValue(forKey: "scroll") as? Bool ?? false
        }
        set {
            updateBookValue(newValue, forKey: "scroll")
            submitToNavigator()
        }
    }

    var spread: Bool {
        get {
            bookValue(forKey: "spread") as? Bool ?? false
        }
        set {
            updateBookValue(newValue, forKey: "spread")
            submitToNavigator()
        }
    }

    var textDirection: ReadiumNavigator.ReadingProgression? {
        get { bookValue(forKey: "textDirection") as? ReadiumNavigator.ReadingProgression }
        set {
            updateBookValue(newValue, forKey: "textDirection")
            submitToNavigator()
        }
    }

    var verticalText: Bool {
        get {
            bookValue(forKey: "verticalText") as? Bool ?? false
        }
        set {
            updateBookValue(newValue, forKey: "verticalText")
            submitToNavigator()
        }
    }

    // MARK: - Global Appearance Preferences

    var fontSize: Double {
        get {
            _ = appearanceUpdateTrigger
            return ReaderAppearancePreferences.fontScale
        }
        set {
            ReaderAppearancePreferences.fontScale = newValue
            appearanceDidChange()
        }
    }

    var selectedFontFamilyOption: ReaderFontFamilyOption {
        _ = appearanceUpdateTrigger
        return ReaderAppearancePreferences.fontFamilyOption
    }

    var horizontalMargin: Double {
        ReaderAppearanceThemeCatalog.navigatorHorizontalInset
    }

    // MARK: - Effective Values (showing what navigator actually uses)

    var effectiveFontSize: Double {
        let rawValue = fontSize
        return rawValue != 0.0 ? rawValue : ReaderAppearancePreferences.fontScaleDefault
    }

    var isUsingDefaultFontSize: Bool {
        fontSize == 0.0
    }

    // MARK: - Effective Book Settings (navigator-inferred values)

    var effectiveScroll: Bool {
        navigator?.settings.scroll ?? scroll
    }

    var isScrollInferred: Bool {
        bookValue(forKey: "scroll") == nil
    }

    var effectiveVerticalText: Bool {
        navigator?.settings.verticalText ?? verticalText
    }

    var isVerticalTextInferred: Bool {
        bookValue(forKey: "verticalText") == nil
    }

    var effectiveReadingProgression: ReadiumNavigator.ReadingProgression {
        navigator?.settings.readingProgression ?? (textDirection ?? .ltr)
    }

    var isReadingProgressionInferred: Bool {
        bookValue(forKey: "textDirection") == nil
    }

    var effectiveSpread: Spread {
        if let navigatorSpread = navigator?.settings.spread {
            return navigatorSpread
        }
        if let spreadValue = bookValue(forKey: "spread") as? Bool {
            return spreadValue ? .always : .never
        }
        return .auto
    }

    var isSpreadInferred: Bool {
        bookValue(forKey: "spread") == nil
    }

    // MARK: - Theme Colors

    var currentPageBackgroundColor: SwiftUI.Color {
        resolvedAppearanceTheme.pageBackgroundColor
    }

    var currentInterfaceBackgroundColor: SwiftUI.Color {
        resolvedAppearanceTheme.interfaceBackgroundColor
    }

    var currentInterfaceForegroundColor: SwiftUI.Color {
        resolvedAppearanceTheme.interfaceForegroundColor
    }

    var currentInterfaceSecondaryColor: SwiftUI.Color {
        resolvedAppearanceTheme.interfaceSecondaryColor
    }

    init(
        bookID: NSManagedObjectID,
        persistenceController: BookDataPersistenceController = .shared,
        context: NSManagedObjectContext? = nil
    ) {
        self.bookID = bookID
        self.context = context ?? persistenceController.container.viewContext
    }

    // MARK: - Navigator Integration

    var selectedAppearanceMode: ReaderAppearanceMode {
        _ = appearanceUpdateTrigger
        return ReaderAppearancePreferences.appearanceMode
    }

    func setFontFamilyOption(_ option: ReaderFontFamilyOption) {
        ReaderAppearancePreferences.fontFamilyOption = option
        appearanceDidChange()
    }

    func setAppearanceMode(_ mode: ReaderAppearanceMode) {
        ReaderAppearancePreferences.appearanceMode = mode
        appearanceDidChange()
    }

    /// Builds EPUBPreferences from current stored values
    func buildEPUBPreferences() -> EPUBPreferences {
        var preferences = EPUBPreferences()

        if let scrollValue = bookValue(forKey: "scroll") as? Bool {
            preferences.scroll = scrollValue
        }

        // Readium hardcodes some preferences like turning off pagination for vertical text,
        // so we always set verticalText to false.
        preferences.verticalText = false

        if let spreadValue = bookValue(forKey: "spread") as? Bool {
            preferences.spread = spreadValue ? .always : .never
        }

        if let textDirection = bookValue(forKey: "textDirection") as? ReadiumNavigator.ReadingProgression {
            preferences.readingProgression = textDirection
        }

        let effectiveFontSize = fontSize
        if effectiveFontSize != 0.0 {
            preferences.fontSize = effectiveFontSize / 100.0
        }

        if ReaderAppearancePreferences.hasStoredFontFamilyOption {
            preferences.fontFamily = FontFamily(rawValue: selectedFontFamilyOption.fontFamilyStack)
        }
        preferences.pageMargins = 0

        switch selectedAppearanceMode {
        case .followSystem:
            preferences.theme = systemColorScheme == .dark ? .dark : .light
        case .light:
            preferences.theme = .light
        case .dark:
            preferences.theme = .dark
        case .sepia:
            preferences.theme = .sepia
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

    /// Increase the font size within reasonable bounds
    func increaseFontSize() {
        fontSize = min(currentFontSizeForAdjustment() + 10.0, 200.0)
    }

    /// Decrease the font size within reasonable bounds
    func decreaseFontSize() {
        fontSize = max(currentFontSizeForAdjustment() - 10.0, 50.0)
    }

    /// Uses the stored override when set, otherwise the effective default size.
    private func currentFontSizeForAdjustment() -> Double {
        let rawSize = fontSize
        return rawSize != 0.0 ? rawSize : effectiveFontSize
    }

    private var resolvedAppearanceTheme: ReaderAppearanceTheme {
        _ = appearanceUpdateTrigger
        _ = systemColorScheme
        return ReaderAppearanceThemeCatalog.resolvedTheme(
            for: selectedAppearanceMode,
            systemColorScheme: systemColorScheme
        )
    }

    private func appearanceDidChange() {
        appearanceUpdateTrigger += 1
        submitToNavigator()
    }

    private func bookObject() -> Book? {
        guard let book = try? context.existingObject(with: bookID) as? Book else {
            return nil
        }
        return book
    }

    private func bookValue(forKey key: String) -> Any? {
        bookObject()?.value(forKey: key)
    }

    private func updateBookValue(_ value: Any?, forKey key: String) {
        guard let book = bookObject() else { return }
        book.setValue(value, forKey: key)
        saveContext()
    }

    private func saveContext() {
        saveContextDebounceTask?.cancel()
        saveContextDebounceTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 500_000_000)
            } catch {
                return
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
}
