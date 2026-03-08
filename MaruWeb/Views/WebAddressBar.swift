// WebAddressBar.swift
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

import SwiftUI

struct WebAddressBar: View {
    @ScaledMetric(relativeTo: .body) private var goButtonSize: CGFloat = 18

    @Binding var text: String
    var showsGoButton: Bool = true
    var onEditingChanged: ((Bool) -> Void)?
    var onSubmit: () -> Void

    @FocusState private var isFocused: Bool
    @State private var selection: TextSelection?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .foregroundStyle(.secondary)

            TextField(
                "",
                text: $text,
                selection: $selection,
                prompt: Text(WebLocalization.string("Search or enter URL", comment: "A placeholder text for a text field in a web address bar."))
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.go)
            .focused($isFocused)
            .onSubmit(onSubmit)
            .onChange(of: isFocused) { _, newValue in
                onEditingChanged?(newValue)
                if newValue, !text.isEmpty {
                    selection = TextSelection(range: text.startIndex ..< text.endIndex)
                }
            }

            if showsGoButton {
                Button(action: onSubmit) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: goButtonSize))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Go")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
