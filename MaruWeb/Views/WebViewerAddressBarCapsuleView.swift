// WebViewerAddressBarCapsuleView.swift
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

struct WebViewerAddressBarCapsuleView: View {
    @Binding var addressText: String
    @Binding var addressSelection: TextSelection?
    @Binding var shouldFocus: Bool
    let isEditingAddress: Bool
    let displayText: String
    let namespace: Namespace.ID
    let iconSize: CGFloat
    let onBeginEditing: () -> Void
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.system(size: iconSize - 2, weight: .semibold))

            ZStack(alignment: .leading) {
                if !isEditingAddress {
                    Button(action: onBeginEditing) {
                        Text(displayText)
                            .font(.subheadline)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }

                TextField(
                    "",
                    text: $addressText,
                    selection: $addressSelection,
                    prompt: Text(WebLocalization.string("Search or enter URL", comment: "A placeholder text for a text field in a web address bar."))
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($isFocused)
                .opacity(isEditingAddress ? 1 : 0)
                .disabled(!isEditingAddress)
                .onSubmit(onSubmit)
                .onChange(of: isFocused, handleFocusStateChange)
                .onChange(of: shouldFocus, handleRequestedFocusChange)
            }
            .padding(.vertical, 10)

            if isEditingAddress, !addressText.isEmpty {
                Button(action: clearAddressText) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: iconSize, weight: .regular))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear text")
            }
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 14)
        .glassEffect(in: Capsule())
        .glassEffectID("address", in: namespace)
        .glassEffectTransition(.matchedGeometry)
    }

    private func handleFocusStateChange(_: Bool, _ newValue: Bool) {
        if shouldFocus != newValue {
            shouldFocus = newValue
        }
    }

    private func handleRequestedFocusChange(_: Bool, _ newValue: Bool) {
        if isFocused != newValue {
            isFocused = newValue
        }
    }

    private func clearAddressText() {
        addressText = ""
    }
}
