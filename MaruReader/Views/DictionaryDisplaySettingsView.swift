// DictionaryDisplaySettingsView.swift
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

import MaruReaderCore
import SwiftUI

struct DictionaryDisplaySettingsView: View {
    private static let fontOptions: [(displayName: String, family: String)] = [
        (String(localized: "Sans Serif"), DictionaryDisplayFontFamilyStacks.sansSerif),
        (String(localized: "Serif"), DictionaryDisplayFontFamilyStacks.serif),
        (String(localized: "Monospace"), DictionaryDisplayFontFamilyStacks.monospace),
    ]

    @AppStorage(DictionaryDisplayPreferences.fontFamilyKey)
    private var storedFontFamily = DictionaryDisplayPreferences.fontFamilyDefault
    @AppStorage(DictionaryDisplayPreferences.fontSizeKey)
    private var fontSize = DictionaryDisplayPreferences.fontSizeDefault
    @AppStorage(DictionaryDisplayPreferences.popupFontSizeKey)
    private var popupFontSize = DictionaryDisplayPreferences.popupFontSizeDefault
    @AppStorage(DictionaryDisplayPreferences.showDeinflectionKey)
    private var showDeinflection = DictionaryDisplayPreferences.showDeinflectionDefault
    @AppStorage(DictionaryDisplayPreferences.deinflectionDescriptionLanguageKey)
    private var deinflectionDescriptionLanguageRawValue = DictionaryDisplayPreferences.deinflectionDescriptionLanguageDefault
    @AppStorage(DictionaryDisplayPreferences.pitchDownstepNotationInHeaderEnabledKey)
    private var pitchDownstepNotationInHeaderEnabled = DictionaryDisplayPreferences.pitchDownstepNotationInHeaderEnabledDefault
    @AppStorage(DictionaryDisplayPreferences.pitchResultsAreaCollapsedDisplayKey)
    private var pitchResultsAreaCollapsedDisplay = DictionaryDisplayPreferences.pitchResultsAreaCollapsedDisplayDefault
    @AppStorage(DictionaryDisplayPreferences.pitchResultsAreaDownstepNotationEnabledKey)
    private var pitchResultsAreaDownstepNotationEnabled = DictionaryDisplayPreferences.pitchResultsAreaDownstepNotationEnabledDefault
    @AppStorage(DictionaryDisplayPreferences.pitchResultsAreaDownstepPositionEnabledKey)
    private var pitchResultsAreaDownstepPositionEnabled = DictionaryDisplayPreferences.pitchResultsAreaDownstepPositionEnabledDefault
    @AppStorage(DictionaryDisplayPreferences.pitchResultsAreaEnabledKey)
    private var pitchResultsAreaEnabled = DictionaryDisplayPreferences.pitchResultsAreaEnabledDefault
    @AppStorage(DictionaryDisplayPreferences.contextFontSizeKey)
    private var contextFontSize = DictionaryDisplayPreferences.contextFontSizeDefault
    @AppStorage(DictionaryDisplayPreferences.contextFuriganaEnabledKey)
    private var contextFuriganaEnabled = DictionaryDisplayPreferences.contextFuriganaEnabledDefault

    @State private var selectedFontIndex: Int

    private var fontFamily: String {
        Self.fontOptions[selectedFontIndex].family
    }

    private static func fontIndex(for family: String) -> Int {
        fontOptions.firstIndex(where: { $0.family == family }) ?? 0
    }

    private var deinflectionDescriptionLanguage: Binding<DeinflectionLanguage> {
        Binding(
            get: {
                DeinflectionLanguage(rawValue: deinflectionDescriptionLanguageRawValue) ?? .followSystem
            },
            set: { newValue in
                deinflectionDescriptionLanguageRawValue = newValue.rawValue
            }
        )
    }

    init() {
        let defaultFamily = DictionaryDisplayPreferences.fontFamily
        let defaultIndex = Self.fontIndex(for: defaultFamily)
        _selectedFontIndex = State(initialValue: defaultIndex)
    }

    var body: some View {
        Form {
            Section("Font Family") {
                Picker("Font Family", selection: $selectedFontIndex) {
                    ForEach(0 ..< Self.fontOptions.count, id: \.self) { index in
                        Text(Self.fontOptions[index].displayName).tag(index)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Font Size Scale") {
                Stepper("Content: \(fontSize.formatted(.number.precision(.fractionLength(2))))x", value: $fontSize, in: 0.5 ... 3.0, step: 0.05)
                Stepper("Popup: \(popupFontSize.formatted(.number.precision(.fractionLength(2))))x", value: $popupFontSize, in: 0.5 ... 3.0, step: 0.05)
            }

            Section("Display Options") {
                Toggle("Show Deinflection Info", isOn: $showDeinflection)
                if showDeinflection {
                    Picker("Deinflection Language", selection: deinflectionDescriptionLanguage) {
                        ForEach(DeinflectionLanguage.allCases, id: \.self) { language in
                            Text(language.displayLabel).tag(language)
                        }
                    }
                }
            }

            Section("Pitch Accent") {
                Toggle("Downstep Notation in Header", isOn: $pitchDownstepNotationInHeaderEnabled)
                Toggle("Show Pitch Dictionaries", isOn: $pitchResultsAreaEnabled)

                if pitchResultsAreaEnabled {
                    Toggle("Top Result Only", isOn: $pitchResultsAreaCollapsedDisplay)
                    Toggle("Show Downstep Notation", isOn: $pitchResultsAreaDownstepNotationEnabled)
                    Toggle("Show Downstep Positions", isOn: $pitchResultsAreaDownstepPositionEnabled)
                }
            }

            Section("Context Display") {
                Stepper("Font Size: \(contextFontSize.formatted(.number.precision(.fractionLength(1))))x", value: $contextFontSize, in: 0.5 ... 2.0, step: 0.1)
                Toggle("Show Furigana", isOn: $contextFuriganaEnabled)
            }
        }
        .navigationTitle("Display Settings")
        .onAppear {
            let normalizedFontFamily = DictionaryDisplayPreferences.fontFamily
            if storedFontFamily != normalizedFontFamily {
                storedFontFamily = normalizedFontFamily
            }
            selectedFontIndex = Self.fontIndex(for: normalizedFontFamily)
        }
        .onChange(of: selectedFontIndex) { _, _ in
            storedFontFamily = fontFamily
        }
        .onChange(of: storedFontFamily) { _, newValue in
            let normalizedValue = DictionaryDisplayFontFamilyStacks.normalize(newValue)
            if normalizedValue != newValue {
                storedFontFamily = normalizedValue
                return
            }
            selectedFontIndex = Self.fontIndex(for: normalizedValue)
        }
    }
}

#Preview {
    DictionaryDisplaySettingsView()
}
