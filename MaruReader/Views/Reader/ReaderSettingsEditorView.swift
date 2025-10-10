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

                ProfilesTab(preferences: preferences)
                    .tabItem {
                        Label("Profiles", systemImage: "person.crop.circle")
                    }
                    .tag(1)

                ThemesTab(preferences: preferences)
                    .tabItem {
                        Label("Themes", systemImage: "paintpalette")
                    }
                    .tag(2)
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
                VStack(spacing: 12) {
                    HStack {
                        Text("Size")
                        Spacer()
                        if preferences.isUsingDefaultFontSize {
                            Text("100% (Default)")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(Int(preferences.fontSize))%")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Slider(
                        value: Binding(
                            get: { preferences.effectiveFontSize },
                            set: { preferences.fontSize = $0 }
                        ),
                        in: 50 ... 200,
                        step: 5
                    )
                }

                HStack {
                    Text("Family")
                    Spacer()
                    Text(preferences.fontFamily ?? "Default")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Margins") {
                VStack(spacing: 12) {
                    HStack {
                        Text("Horizontal")
                        Spacer()
                        if preferences.isUsingDefaultHorizontalMargin {
                            Text("1.0 (Default)")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(preferences.horizontalMargin, specifier: "%.2f")")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Slider(
                        value: Binding(
                            get: { preferences.effectiveHorizontalMargin },
                            set: { preferences.horizontalMargin = $0 }
                        ),
                        in: 0.5 ... 3.0,
                        step: 0.25
                    )
                }

                VStack(spacing: 12) {
                    HStack {
                        Text("Vertical")
                        Spacer()
                        if preferences.isUsingDefaultVerticalMargin {
                            Text("1.0 (Default)")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(preferences.verticalMargin, specifier: "%.2f")")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Slider(
                        value: Binding(
                            get: { preferences.effectiveVerticalMargin },
                            set: { preferences.verticalMargin = $0 }
                        ),
                        in: 0.5 ... 3.0,
                        step: 0.25
                    )
                }
            }
        }
    }
}

// MARK: - Profiles Tab

struct ProfilesTab: View {
    let preferences: ReaderPreferences
    @State private var profiles: [ReaderProfile] = []

    var body: some View {
        Form {
            Section("Current Profile") {
                if let profile = preferences.profile {
                    HStack {
                        ProfileIconView(profile: profile, size: 32)
                        VStack(alignment: .leading) {
                            Text(profile.name ?? "Unnamed")
                                .font(.headline)
                            if profile.isDefault {
                                Text("Default Profile")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("Available Profiles") {
                ForEach(profiles, id: \.id) { profile in
                    Button {
                        preferences.setProfile(profile)
                    } label: {
                        HStack {
                            ProfileIconView(profile: profile, size: 32)
                            VStack(alignment: .leading) {
                                Text(profile.name ?? "Unnamed")
                                    .foregroundStyle(.primary)
                                if profile.isDefault {
                                    Text("Default")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if profile == preferences.profile {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    // TODO: Create new profile
                } label: {
                    Label("Create New Profile", systemImage: "plus")
                }
            }
        }
        .onAppear {
            profiles = preferences.fetchAllProfiles()
        }
    }
}

// MARK: - Themes Tab

struct ThemesTab: View {
    let preferences: ReaderPreferences
    @State private var themes: [ReaderTheme] = []

    var body: some View {
        Form {
            Section("System Themes") {
                ForEach(themes.filter(\.isSystemTheme), id: \.id) { theme in
                    HStack {
                        ThemeIconView(theme: theme, size: 32)
                        Text(theme.name ?? "Unnamed")
                        Spacer()
                        if isCurrentTheme(theme) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }

            if !themes.filter({ !$0.isSystemTheme }).isEmpty {
                Section("Custom Themes") {
                    ForEach(themes.filter { !$0.isSystemTheme }, id: \.id) { theme in
                        HStack {
                            ThemeIconView(theme: theme, size: 32)
                            Text(theme.name ?? "Unnamed")
                            Spacer()
                            if isCurrentTheme(theme) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
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

    private func isCurrentTheme(_ theme: ReaderTheme) -> Bool {
        guard let currentTheme = preferences.currentTheme else { return false }
        return currentTheme == theme
    }
}
