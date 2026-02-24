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

import CoreData
import MaruReaderCore
import SwiftUI

struct DictionaryDisplaySettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        entity: DictionaryDisplayPreferences.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \DictionaryDisplayPreferences.id, ascending: true)],
        predicate: NSPredicate(format: "enabled == %@", NSNumber(value: true)),
        animation: .default
    ) private var activePreferences: FetchedResults<DictionaryDisplayPreferences>

    @State private var selectedFontIndex: Int = 0
    @State private var fontSize: Double = DictionaryDisplayDefaults.defaultFontSize
    @State private var popupFontSize: Double = DictionaryDisplayDefaults.defaultPopupFontSize
    @State private var showDeinflection: Bool = DictionaryDisplayDefaults.defaultShowDeinflection
    @State private var deinflectionDescriptionLanguage: DeinflectionLanguage = .init(rawValue: DictionaryDisplayDefaults.defaultDeinflectionDescriptionLanguage) ?? .followSystem
    @State private var pitchDownstepNotationInHeaderEnabled: Bool = DictionaryDisplayDefaults.defaultPitchDownstepNotationInHeaderEnabled
    @State private var pitchResultsAreaCollapsedDisplay: Bool = DictionaryDisplayDefaults.defaultPitchResultsAreaCollapsedDisplay
    @State private var pitchResultsAreaDownstepNotationEnabled: Bool = DictionaryDisplayDefaults.defaultPitchResultsAreaDownstepNotationEnabled
    @State private var pitchResultsAreaDownstepPositionEnabled: Bool = DictionaryDisplayDefaults.defaultPitchResultsAreaDownstepPositionEnabled
    @State private var pitchResultsAreaEnabled: Bool = DictionaryDisplayDefaults.defaultPitchResultsAreaEnabled

    // Context display settings
    @State private var contextFontSize: Double = DictionaryDisplayDefaults.defaultContextFontSize
    @State private var contextFuriganaEnabled: Bool = DictionaryDisplayDefaults.defaultContextFuriganaEnabled

    private let fontOptions: [(displayName: String, family: String)] = [
        ("System", "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif"),
        ("Serif", "Hiragino Mincho ProN, TimesNewRomanPSMT, 'Times New Roman', Times, Georgia, serif"),
        ("Sans Serif", "Hiragino Sans, HelveticaNeue, Helvetica, Arial, sans-serif"),
        ("Monospace", "'Osaka Mono', Menlo, Monaco, 'Courier New', monospace"),
    ]

    private var fontFamily: String {
        fontOptions[selectedFontIndex].family
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Font Family") {
                    Picker("Font Family", selection: $selectedFontIndex) {
                        ForEach(0 ..< fontOptions.count, id: \.self) { index in
                            Text(fontOptions[index].displayName).tag(index)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Font Size Scale") {
                    Stepper("Content: \(fontSize, specifier: "%.2f")x", value: $fontSize, in: 0.5 ... 3.0, step: 0.05)
                    Stepper("Popup: \(popupFontSize, specifier: "%.2f")x", value: $popupFontSize, in: 0.5 ... 3.0, step: 0.05)
                }

                Section("Display Options") {
                    Toggle("Show Deinflection Info", isOn: $showDeinflection)
                    if showDeinflection {
                        Picker("Deinflection Language", selection: $deinflectionDescriptionLanguage) {
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
                    Stepper("Font Size: \(contextFontSize, specifier: "%.1f")x", value: $contextFontSize, in: 0.5 ... 2.0, step: 0.1)
                    Toggle("Show Furigana", isOn: $contextFuriganaEnabled)
                }
            }
            .navigationTitle("Display Settings")
            .onAppear(perform: loadPreferences)
            .onChange(of: activePreferences.count) { _, _ in loadPreferences() }
            .onChange(of: selectedFontIndex) { _, _ in savePreferences() }
            .onChange(of: fontSize) { _, _ in savePreferences() }
            .onChange(of: popupFontSize) { _, _ in savePreferences() }
            .onChange(of: showDeinflection) { _, _ in savePreferences() }
            .onChange(of: deinflectionDescriptionLanguage) { _, _ in savePreferences() }
            .onChange(of: pitchDownstepNotationInHeaderEnabled) { _, _ in savePreferences() }
            .onChange(of: pitchResultsAreaCollapsedDisplay) { _, _ in savePreferences() }
            .onChange(of: pitchResultsAreaDownstepNotationEnabled) { _, _ in savePreferences() }
            .onChange(of: pitchResultsAreaDownstepPositionEnabled) { _, _ in savePreferences() }
            .onChange(of: pitchResultsAreaEnabled) { _, _ in savePreferences() }
            .onChange(of: contextFontSize) { _, _ in savePreferences() }
            .onChange(of: contextFuriganaEnabled) { _, _ in savePreferences() }
        }
    }

    private func loadPreferences() {
        if let pref = activePreferences.first {
            if let family = pref.fontFamily,
               let index = fontOptions.firstIndex(where: { $0.family == family })
            {
                selectedFontIndex = index
            } else {
                selectedFontIndex = 0
            }
            fontSize = pref.fontSize
            popupFontSize = pref.popupFontSize
            showDeinflection = pref.showDeinflection
            deinflectionDescriptionLanguage = DeinflectionLanguage(rawValue: pref.deinflectionDescriptionLanguage ?? DictionaryDisplayDefaults.defaultDeinflectionDescriptionLanguage) ?? .followSystem
            pitchDownstepNotationInHeaderEnabled = pref.pitchDownstepNotationInHeaderEnabled
            pitchResultsAreaCollapsedDisplay = pref.pitchResultsAreaCollapsedDisplay
            pitchResultsAreaDownstepNotationEnabled = pref.pitchResultsAreaDownstepNotationEnabled
            pitchResultsAreaDownstepPositionEnabled = pref.pitchResultsAreaDownstepPositionEnabled
            pitchResultsAreaEnabled = pref.pitchResultsAreaEnabled
            contextFontSize = pref.contextFontSize
            contextFuriganaEnabled = pref.contextFuriganaEnabled
        } else {
            createDefaultPreferences()
        }
    }

    private func createDefaultPreferences() {
        // Disable existing enabled preferences
        let request: NSFetchRequest<DictionaryDisplayPreferences> = DictionaryDisplayPreferences.fetchRequest()
        request.predicate = NSPredicate(format: "enabled == %@", NSNumber(value: true))
        do {
            let enabledPrefs = try viewContext.fetch(request)
            for pref in enabledPrefs {
                pref.enabled = false
            }
        } catch {
            print("Error disabling existing preferences: \(error)")
        }

        // Create new default
        let newPref = DictionaryDisplayPreferences(context: viewContext)
        newPref.id = UUID()
        newPref.enabled = true
        newPref.fontFamily = DictionaryDisplayDefaults.defaultFontFamily
        newPref.fontSize = DictionaryDisplayDefaults.defaultFontSize
        newPref.popupFontSize = DictionaryDisplayDefaults.defaultPopupFontSize
        newPref.showDeinflection = DictionaryDisplayDefaults.defaultShowDeinflection
        newPref.deinflectionDescriptionLanguage = DictionaryDisplayDefaults.defaultDeinflectionDescriptionLanguage
        newPref.pitchDownstepNotationInHeaderEnabled = DictionaryDisplayDefaults.defaultPitchDownstepNotationInHeaderEnabled
        newPref.pitchResultsAreaCollapsedDisplay = DictionaryDisplayDefaults.defaultPitchResultsAreaCollapsedDisplay
        newPref.pitchResultsAreaDownstepNotationEnabled = DictionaryDisplayDefaults.defaultPitchResultsAreaDownstepNotationEnabled
        newPref.pitchResultsAreaDownstepPositionEnabled = DictionaryDisplayDefaults.defaultPitchResultsAreaDownstepPositionEnabled
        newPref.pitchResultsAreaEnabled = DictionaryDisplayDefaults.defaultPitchResultsAreaEnabled
        newPref.contextFontSize = DictionaryDisplayDefaults.defaultContextFontSize
        newPref.contextFuriganaEnabled = DictionaryDisplayDefaults.defaultContextFuriganaEnabled

        do {
            try viewContext.save()
        } catch {
            print("Error saving default preferences: \(error)")
        }
    }

    private func savePreferences() {
        guard let pref = activePreferences.first else { return }
        pref.fontFamily = fontFamily
        pref.fontSize = fontSize
        pref.popupFontSize = popupFontSize
        pref.showDeinflection = showDeinflection
        pref.deinflectionDescriptionLanguage = deinflectionDescriptionLanguage.rawValue
        pref.pitchDownstepNotationInHeaderEnabled = pitchDownstepNotationInHeaderEnabled
        pref.pitchResultsAreaCollapsedDisplay = pitchResultsAreaCollapsedDisplay
        pref.pitchResultsAreaDownstepNotationEnabled = pitchResultsAreaDownstepNotationEnabled
        pref.pitchResultsAreaDownstepPositionEnabled = pitchResultsAreaDownstepPositionEnabled
        pref.pitchResultsAreaEnabled = pitchResultsAreaEnabled
        pref.contextFontSize = contextFontSize
        pref.contextFuriganaEnabled = contextFuriganaEnabled
        do {
            try viewContext.save()
        } catch {
            print("Error saving preferences: \(error)")
        }
    }
}

#Preview {
    DictionaryDisplaySettingsView()
        .environment(\.managedObjectContext, DictionaryPersistenceController.shared.container.viewContext)
}
