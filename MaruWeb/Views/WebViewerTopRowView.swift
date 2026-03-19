// WebViewerTopRowView.swift
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

import MaruDictionaryUICommon
import SwiftUI

struct WebViewerTopRowView: View {
    @Binding var addressText: String
    @Binding var addressSelection: TextSelection?
    @Binding var isAddressFocused: Bool
    let isEditingAddress: Bool
    let isLoading: Bool
    let displayText: String
    let floatingButtonIconSize: CGFloat
    let floatingButtonFrameSize: CGFloat
    let glassNamespace: Namespace.ID
    let onBeginAddressEditing: () -> Void
    let onCancelAddressEditing: () -> Void
    let onSubmitAddress: () -> Void
    let onEnableReadingMode: () -> Void
    let onStopLoading: () -> Void
    let onReload: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if !isEditingAddress {
                Button(action: onEnableReadingMode) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: floatingButtonIconSize, weight: .semibold))
                }
                .frame(width: floatingButtonFrameSize, height: floatingButtonFrameSize)
                .contentShape(.circle)
                .buttonStyle(.plain)
                .glassEffect(in: Circle())
                .glassEffectID("readingMode", in: glassNamespace)
                .glassEffectTransition(GlassEffectTransition.matchedGeometry)
                .accessibilityLabel("Enable OCR Mode")
                .tourAnchor(WebViewerToolbarTourAnchor.readingModeButton)
            }

            WebViewerAddressBarCapsuleView(
                addressText: $addressText,
                addressSelection: $addressSelection,
                shouldFocus: $isAddressFocused,
                isEditingAddress: isEditingAddress,
                displayText: displayText,
                namespace: glassNamespace,
                iconSize: floatingButtonIconSize,
                onBeginEditing: onBeginAddressEditing,
                onSubmit: onSubmitAddress
            )
            .frame(maxWidth: .infinity)
            .tourAnchor(WebViewerToolbarTourAnchor.addressBar)

            if isEditingAddress {
                Button(action: onCancelAddressEditing) {
                    Image(systemName: "xmark")
                        .font(.system(size: floatingButtonIconSize, weight: .semibold))
                }
                .frame(width: floatingButtonFrameSize, height: floatingButtonFrameSize)
                .contentShape(.circle)
                .buttonStyle(.plain)
                .glassEffect(in: Circle())
                .accessibilityLabel("Cancel")
            } else {
                WebViewerStopReloadButton(
                    isLoading: isLoading,
                    iconSize: floatingButtonIconSize,
                    frameSize: floatingButtonFrameSize,
                    onStopLoading: onStopLoading,
                    onReload: onReload
                )
            }
        }
    }
}
