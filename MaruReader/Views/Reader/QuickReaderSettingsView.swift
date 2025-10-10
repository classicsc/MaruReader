//
//  QuickReaderSettingsView.swift
//  MaruReader
//
//  Quick settings menu for reader: font size, margins, and theme selection.
//

import SwiftUI

struct QuickReaderSettingsMenu: View {
    let preferences: ReaderPreferences
    let onOpenFullSettings: () -> Void

    var body: some View {
        Menu {
            // Font Size
            Menu {
                Stepper(
                    value: Binding(
                        get: { preferences.effectiveFontSize },
                        set: { preferences.fontSize = $0 }
                    ),
                    in: 50 ... 200,
                    step: 10
                ) {
                    if preferences.isUsingDefaultFontSize {
                        Text("Font Size: 100% (Default)")
                    } else {
                        Text("Font Size: \(Int(preferences.fontSize))%")
                    }
                }
            } label: {
                Label("Font Size", systemImage: "textformat.size")
            }

            // Horizontal Margin
            Menu {
                Stepper(
                    value: Binding(
                        get: { preferences.effectiveHorizontalMargin },
                        set: { preferences.horizontalMargin = $0 }
                    ),
                    in: 0.5 ... 3.0,
                    step: 0.25
                ) {
                    if preferences.isUsingDefaultHorizontalMargin {
                        Text("Horizontal: 1.0 (Default)")
                    } else {
                        Text("Horizontal: \(preferences.horizontalMargin, specifier: "%.2f")")
                    }
                }
            } label: {
                Label("Horizontal Margin", systemImage: "arrow.left.and.right")
            }

            // Vertical Margin
            Menu {
                Stepper(
                    value: Binding(
                        get: { preferences.effectiveVerticalMargin },
                        set: { preferences.verticalMargin = $0 }
                    ),
                    in: 0.5 ... 3.0,
                    step: 0.25
                ) {
                    if preferences.isUsingDefaultVerticalMargin {
                        Text("Vertical: 1.0 (Default)")
                    } else {
                        Text("Vertical: \(preferences.verticalMargin, specifier: "%.2f")")
                    }
                }
            } label: {
                Label("Vertical Margin", systemImage: "arrow.up.and.down")
            }

            Divider()

            // Theme info (read-only in quick menu)
            if let profile = preferences.profile {
                if let theme = profile.theme, profile.darkTheme == nil {
                    Label("Theme: \(theme.name ?? "Unknown")", systemImage: "paintpalette")
                } else if let lightTheme = profile.theme, let darkTheme = profile.darkTheme {
                    Label("Themes: \(lightTheme.name ?? "Light") / \(darkTheme.name ?? "Dark")", systemImage: "paintpalette")
                }
            }

            Divider()

            Button {
                onOpenFullSettings()
            } label: {
                Label("More Settings...", systemImage: "gearshape")
            }
        } label: {
            Image(systemName: "textformat.size.ja")
        }
    }
}
