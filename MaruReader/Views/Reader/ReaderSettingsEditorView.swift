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
                Toggle("Scrolling", isOn: Binding(
                    get: { preferences.scroll },
                    set: { preferences.scroll = $0 }
                ))

                Toggle("2-Page Spread", isOn: Binding(
                    get: { preferences.spread },
                    set: { preferences.spread = $0 }
                ))

                Toggle("Vertical Text", isOn: Binding(
                    get: { preferences.verticalText },
                    set: { preferences.verticalText = $0 }
                ))
            }

            Section("Text Direction") {
                Picker("Direction", selection: Binding(
                    get: { preferences.textDirection ?? .ltr },
                    set: { preferences.textDirection = $0 }
                )) {
                    Text("Left to Right").tag(ReadiumNavigator.ReadingProgression.ltr)
                    Text("Right to Left").tag(ReadiumNavigator.ReadingProgression.rtl)
                }
                .pickerStyle(.segmented)
            }

            Section("Font") {
                VStack(spacing: 12) {
                    HStack {
                        Text("Size")
                        Spacer()
                        Text("\(Int(preferences.fontSize))%")
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { preferences.fontSize },
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
                        Text("\(preferences.horizontalMargin, specifier: "%.2f")")
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { preferences.horizontalMargin },
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
                        Text("\(preferences.verticalMargin, specifier: "%.2f")")
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { preferences.verticalMargin },
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
