// WebViewerCollapsedAddressCapsuleView.swift
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

struct WebViewerCollapsedAddressCapsuleView: View {
    let displayText: String
    let namespace: Namespace.ID
    let iconSize: CGFloat
    let maxWidth: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: iconSize - 2, weight: .semibold))

                Text(displayText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .font(.subheadline)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .frame(maxWidth: maxWidth)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(in: Capsule())
        .glassEffectID("address", in: namespace)
        .glassEffectTransition(.matchedGeometry)
        .accessibilityLabel("Show Controls")
    }
}
