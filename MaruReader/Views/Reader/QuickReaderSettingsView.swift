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
            Stepper(
                value: Binding(
                    get: { preferences.effectiveFontSize },
                    set: { preferences.fontSize = $0 }
                ),
                in: 50 ... 200,
                step: 10,
                label: {
                    Label("Font Size", systemImage: "textformat.size")
                }
            )

            // Horizontal Margin
            Stepper(
                value: Binding(
                    get: { preferences.effectiveHorizontalMargin },
                    set: { preferences.horizontalMargin = $0 }
                ),
                in: 0.5 ... 3.0,
                step: 0.25,
                label: {
                    Label("Margin", systemImage: "arrow.left.and.right")
                }
            )

            Divider()

            // Theme info (read-only in quick menu)
            if let lightTheme = preferences.lightTheme {
                if preferences.darkTheme == nil {
                    Label("Theme: \(lightTheme.name ?? "Unknown")", systemImage: "paintpalette")
                } else if let darkTheme = preferences.darkTheme {
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
