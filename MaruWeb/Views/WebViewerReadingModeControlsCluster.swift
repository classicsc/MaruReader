// WebViewerReadingModeControlsCluster.swift
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

struct WebViewerReadingModeControlsCluster: View {
    let showBoundingBoxes: Bool
    let iconSize: CGFloat
    let frameSize: CGFloat
    let namespace: Namespace.ID
    let onToggleBoundingBoxes: () -> Void
    let onDisableReadingMode: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onToggleBoundingBoxes) {
                Image(systemName: showBoundingBoxes ? "text.viewfinder" : "viewfinder")
                    .font(.system(size: iconSize, weight: .semibold))
            }
            .frame(width: frameSize, height: frameSize)
            .contentShape(.rect)
            .buttonStyle(.plain)
            .accessibilityLabel(
                showBoundingBoxes
                    ? Text("Hide text regions")
                    : Text("Show text regions")
            )

            Divider()
                .frame(height: frameSize - 12)

            Button(action: onDisableReadingMode) {
                Image(systemName: "xmark")
                    .font(.system(size: iconSize, weight: .semibold))
            }
            .frame(width: frameSize, height: frameSize)
            .contentShape(.rect)
            .buttonStyle(.plain)
            .accessibilityLabel("Exit OCR Mode")
        }
        .padding(.horizontal, 2)
        .glassEffect(in: Capsule())
        .glassEffectID("readingMode", in: namespace)
        .glassEffectTransition(.matchedGeometry)
    }
}
