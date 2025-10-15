//
//  ReaderSettingsEditorView.swift
//  MaruReader
//
//  Full reader settings editor with profile and theme management.
//

import ReadiumNavigator
import SwiftUI

struct ReaderSettingsEditorView: View {
    let preferences: ReaderPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                ReadingSettingsTab(preferences: preferences)
                    .tabItem {
                        Label("Reading", systemImage: "book")
                    }
                    .tag(0)

                ThemesTab(preferences: preferences)
                    .tabItem {
                        Label("Themes", systemImage: "paintpalette")
                    }
                    .tag(1)
            }
            .navigationTitle("Reader Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Reading Settings Tab

struct ReadingSettingsTab: View {
    let preferences: ReaderPreferences

    var body: some View {
        Form {
            Section("Display Mode") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Scrolling", isOn: Binding(
                        get: { preferences.effectiveScroll },
                        set: { preferences.scroll = $0 }
                    ))
                    if preferences.isScrollInferred {
                        Text("Automatically determined from publication")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Only show spread option for fixed-layout EPUBs
                if preferences.isFixedLayout {
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("2-Page Spread", isOn: Binding(
                            get: { preferences.effectiveSpread == .always },
                            set: { preferences.spread = $0 }
                        ))
                        if preferences.isSpreadInferred {
                            Text("Automatically determined from publication")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Vertical Text", isOn: Binding(
                        get: { preferences.effectiveVerticalText },
                        set: { preferences.verticalText = $0 }
                    ))
                    if preferences.isVerticalTextInferred {
                        Text("Automatically determined from publication")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Text Direction") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Direction", selection: Binding(
                        get: { preferences.effectiveReadingProgression },
                        set: { preferences.textDirection = $0 }
                    )) {
                        Text("Left to Right").tag(ReadiumNavigator.ReadingProgression.ltr)
                        Text("Right to Left").tag(ReadiumNavigator.ReadingProgression.rtl)
                    }
                    .pickerStyle(.segmented)

                    if preferences.isReadingProgressionInferred {
                        Text("Automatically determined from publication language")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Font") {
                Stepper(
                    value: Binding(
                        get: { preferences.effectiveFontSize },
                        set: { preferences.fontSize = $0 }
                    ),
                    in: 50 ... 200,
                    step: 5,
                    label: {
                        Text("Size")
                    }
                )

                HStack {
                    Text("Family")
                    Spacer()
                    Text(preferences.fontFamily ?? "Default")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Margins") {
                VStack(spacing: 12) {
                    Stepper(
                        value: Binding(
                            get: { preferences.effectiveHorizontalMargin },
                            set: { preferences.horizontalMargin = $0 }
                        ),
                        in: 0.5 ... 3.0,
                        step: 0.25,
                        label: { Text("Horizontal") }
                    )
                }
            }
        }
    }
}

// MARK: - Themes Tab

struct ThemesTab: View {
    let preferences: ReaderPreferences
    @State private var themes: [ReaderTheme] = []

    var body: some View {
        Form {
            Section {
                Toggle("Follow System", isOn: Binding(
                    get: { preferences.isFollowingSystemTheme },
                    set: { preferences.setFollowSystemTheme($0) }
                ))
            } footer: {
                Text(preferences.isFollowingSystemTheme
                    ? "Automatically switch between light and dark themes based on system appearance"
                    : "Use the same theme regardless of system appearance")
            }

            if preferences.isFollowingSystemTheme {
                // Dual theme mode: separate sections for light and dark
                Section("Light Mode Theme") {
                    ForEach(themes.filter(\.isSystemTheme), id: \.id) { theme in
                        themeRow(theme: theme, isLightMode: true)
                    }
                }

                if !themes.filter({ !$0.isSystemTheme }).isEmpty {
                    Section("Light Mode - Custom Themes") {
                        ForEach(themes.filter { !$0.isSystemTheme }, id: \.id) { theme in
                            themeRow(theme: theme, isLightMode: true)
                        }
                    }
                }

                Section("Dark Mode Theme") {
                    ForEach(themes.filter(\.isSystemTheme), id: \.id) { theme in
                        themeRow(theme: theme, isLightMode: false)
                    }
                }

                if !themes.filter({ !$0.isSystemTheme }).isEmpty {
                    Section("Dark Mode - Custom Themes") {
                        ForEach(themes.filter { !$0.isSystemTheme }, id: \.id) { theme in
                            themeRow(theme: theme, isLightMode: false)
                        }
                    }
                }
            } else {
                // Single theme mode
                Section("System Themes") {
                    ForEach(themes.filter(\.isSystemTheme), id: \.id) { theme in
                        themeRow(theme: theme, isLightMode: nil)
                    }
                }

                if !themes.filter({ !$0.isSystemTheme }).isEmpty {
                    Section("Custom Themes") {
                        ForEach(themes.filter { !$0.isSystemTheme }, id: \.id) { theme in
                            themeRow(theme: theme, isLightMode: nil)
                        }
                    }
                }
            }

            Section {
                Button {
                    // TODO: Create new theme
                } label: {
                    Label("Create New Theme", systemImage: "plus")
                }
            }
        }
        .onAppear {
            themes = preferences.fetchAllThemes()
        }
    }

    @ViewBuilder
    private func themeRow(theme: ReaderTheme, isLightMode: Bool?) -> some View {
        Button {
            selectTheme(theme, isLightMode: isLightMode)
        } label: {
            HStack {
                ThemeIconView(theme: theme, size: 32)
                Text(theme.name ?? "Unnamed")
                    .foregroundStyle(.primary)
                Spacer()
                if isThemeSelected(theme, isLightMode: isLightMode) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
        }
    }

    private func isThemeSelected(_ theme: ReaderTheme, isLightMode: Bool?) -> Bool {
        if let isLightMode {
            // Dual theme mode
            if isLightMode {
                preferences.lightTheme == theme
            } else {
                preferences.darkTheme == theme
            }
        } else {
            // Single theme mode
            preferences.lightTheme == theme
        }
    }

    private func selectTheme(_ theme: ReaderTheme, isLightMode: Bool?) {
        if let isLightMode {
            // Dual theme mode
            if isLightMode {
                preferences.setLightTheme(theme)
            } else {
                preferences.setDarkTheme(theme)
            }
        } else {
            // Single theme mode
            preferences.setLightTheme(theme)
        }
    }
}
