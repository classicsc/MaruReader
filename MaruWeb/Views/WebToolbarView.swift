// WebToolbarView.swift
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

struct WebToolbarView: View {
    @Binding var addressText: String
    let isLoading: Bool
    let estimatedProgress: Double
    let canGoBack: Bool
    let canGoForward: Bool
    let isReadingModeEnabled: Bool
    let pagingMode: ReadingPagingMode
    let isBookmarked: Bool
    var onAddressEditingChanged: ((Bool) -> Void)?
    let onSubmitAddress: () -> Void
    let onBack: () -> Void
    let onForward: () -> Void
    let onReload: () -> Void
    let onStopLoading: () -> Void
    let onBookmark: () -> Void
    let onToggleReadingMode: () -> Void
    let onTogglePagingMode: () -> Void
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Loading progress indicator
            if isLoading {
                ProgressView(value: estimatedProgress)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
            }

            // Main toolbar content
            VStack(spacing: 8) {
                // First row: Address bar
                HStack(spacing: 16) {
                    // Address bar (central, flexible)
                    WebAddressBar(
                        text: $addressText,
                        showsGoButton: false,
                        onEditingChanged: onAddressEditingChanged,
                        onSubmit: onSubmitAddress
                    )

                    // Reload/Stop button
                    Button(action: isLoading ? onStopLoading : onReload) {
                        Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .accessibilityLabel(isLoading ? "Stop" : "Reload")
                }

                // Second row: Additional controls
                HStack(spacing: 16) {
                    // Navigation buttons
                    Button(action: onBack) {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .disabled(!canGoBack)
                    .accessibilityLabel("Back")
                    Spacer()

                    Button(action: onForward) {
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .disabled(!canGoForward)
                    .accessibilityLabel("Forward")
                    Spacer()
                    Button(action: onExit) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .accessibilityLabel("Exit Web Viewer")
                    Spacer()
                    Button(action: onBookmark) {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundStyle(isBookmarked ? Color.accentColor : .primary)
                    .accessibilityLabel(isBookmarked ? "Remove Bookmark" : "Add Bookmark")

                    Spacer()
                    Button(action: onToggleReadingMode) {
                        Image(systemName: isReadingModeEnabled ? "hand.tap.fill" : "hand.tap")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundStyle(isReadingModeEnabled ? Color.accentColor : .primary)
                    .accessibilityLabel(isReadingModeEnabled ? "Disable Reading Mode" : "Enable Reading Mode")

                    if isReadingModeEnabled {
                        Button(action: onTogglePagingMode) {
                            Image(systemName: pagingMode == .horizontalPaging ? "arrow.left.arrow.right" : "arrow.up.arrow.down")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .accessibilityLabel(pagingMode == .horizontalPaging ? "Switch to Vertical Scrolling" : "Switch to Horizontal Paging")
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .contentShape(.rect(cornerRadius: 20))
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.clear)
                .glassEffect(in: .rect(cornerRadius: 20))
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}
