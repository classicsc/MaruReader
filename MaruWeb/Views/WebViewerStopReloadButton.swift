// WebViewerStopReloadButton.swift
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

struct WebViewerStopReloadButton: View {
    let isLoading: Bool
    let iconSize: CGFloat
    let frameSize: CGFloat
    let onStopLoading: () -> Void
    let onReload: () -> Void

    var body: some View {
        Button(action: isLoading ? onStopLoading : onReload) {
            Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                .font(.system(size: iconSize, weight: .semibold))
        }
        .frame(width: frameSize, height: frameSize)
        .contentShape(.circle)
        .buttonStyle(.plain)
        .glassEffect(in: Circle())
        .accessibilityLabel(isLoading ? "Stop Loading" : "Reload")
    }
}
