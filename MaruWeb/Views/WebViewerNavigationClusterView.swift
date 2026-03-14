// WebViewerNavigationClusterView.swift
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

struct WebViewerNavigationClusterView: View {
    let canGoBack: Bool
    let canGoForward: Bool
    let iconSize: CGFloat
    let frameSize: CGFloat
    let namespace: Namespace.ID
    let onGoBack: () -> Void
    let onGoForward: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            if canGoBack {
                Button(action: onGoBack) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: iconSize, weight: .semibold))
                }
                .frame(width: frameSize, height: frameSize)
                .contentShape(.rect)
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }

            if canGoBack, canGoForward {
                Divider()
                    .frame(height: frameSize - 12)
            }

            if canGoForward {
                Button(action: onGoForward) {
                    Image(systemName: "chevron.forward")
                        .font(.system(size: iconSize, weight: .semibold))
                }
                .frame(width: frameSize, height: frameSize)
                .contentShape(.rect)
                .buttonStyle(.plain)
                .accessibilityLabel("Forward")
            }
        }
        .padding(.horizontal, 2)
        .glassEffect(in: Capsule())
        .glassEffectID("navCluster", in: namespace)
        .glassEffectTransition(.matchedGeometry)
    }
}
