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
                    get: { preferences.horizontalMargin },
                    set: { preferences.horizontalMargin = $0 }
                ),
                in: 0.0 ... 100.0,
                step: 10.0,
                label: {
                    Label("Margin", systemImage: "arrow.left.and.right")
                }
            )
        } label: {
            Image(systemName: "textformat.size.ja")
        }
    }
}
