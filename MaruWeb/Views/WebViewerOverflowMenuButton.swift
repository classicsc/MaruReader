// WebViewerOverflowMenuButton.swift
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

struct WebViewerOverflowMenuButton: View {
    let floatingButtonIconSize: CGFloat
    let floatingButtonFrameSize: CGFloat
    let glassNamespace: Namespace.ID
    let onDismiss: () -> Void

    var body: some View {
        Menu {
            Button(action: onDismiss) {
                Label {
                    Text(WebLocalization.string("Exit Web Viewer", comment: "A button that exits the web viewer."))
                } icon: {
                    Image(systemName: "xmark")
                }
            }
        } label: {
            ZStack {
                Image(systemName: "ellipsis")
                    .font(.system(size: floatingButtonIconSize, weight: .semibold))

                Color.clear
                    .allowsHitTesting(false)
                    .tourAnchor(WebViewerToolbarTourAnchor.dismissButton)
            }
        }
        .frame(width: floatingButtonFrameSize, height: floatingButtonFrameSize)
        .contentShape(.circle)
        .buttonStyle(.plain)
        .glassEffect(in: Circle())
        .glassEffectID("overflow", in: glassNamespace)
        .glassEffectTransition(.matchedGeometry)
        .accessibilityLabel("More Actions")
    }
}
