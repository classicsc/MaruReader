// QuickReaderSettingsView.swift
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
        .accessibilityLabel("Reader settings")
    }
}
