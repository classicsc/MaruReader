// WebViewerBottomRowView.swift
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

struct WebViewerBottomRowView: View {
    let canGoBack: Bool
    let canGoForward: Bool
    let isBookmarked: Bool
    let bookmarks: [WebBookmarkSnapshot]
    let tabCount: Int
    let floatingButtonIconSize: CGFloat
    let floatingButtonFrameSize: CGFloat
    let glassNamespace: Namespace.ID
    let onGoBack: () -> Void
    let onGoForward: () -> Void
    let onToggleBookmark: () -> Void
    let onNavigateToBookmark: (URL) -> Void
    let onShowTabSwitcher: () -> Void
    let onCollapseToolbar: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            WebViewerNavigationClusterView(
                canGoBack: canGoBack,
                canGoForward: canGoForward,
                iconSize: floatingButtonIconSize,
                frameSize: floatingButtonFrameSize,
                namespace: glassNamespace,
                onGoBack: onGoBack,
                onGoForward: onGoForward
            )

            Spacer()

            WebViewerBookmarkButton(
                isBookmarked: isBookmarked,
                bookmarks: bookmarks,
                iconSize: floatingButtonIconSize,
                frameSize: floatingButtonFrameSize,
                onToggleBookmark: onToggleBookmark,
                onNavigateToBookmark: onNavigateToBookmark
            )
            .tourAnchor(WebViewerToolbarTourAnchor.bookmarkButton)

            Button(action: onShowTabSwitcher) {
                Image(systemName: "square.on.square")
                    .font(.system(size: floatingButtonIconSize, weight: .semibold))
            }
            .frame(width: floatingButtonFrameSize, height: floatingButtonFrameSize)
            .contentShape(.circle)
            .buttonStyle(.plain)
            .glassEffect(in: Circle())
            .overlay(alignment: .topTrailing) {
                Text("\(tabCount)")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.thinMaterial, in: Capsule())
                    .offset(x: 8, y: -8)
            }
            .accessibilityLabel("Tabs")
            .accessibilityValue("\(tabCount)")

            WebViewerOverflowMenuButton(
                floatingButtonIconSize: floatingButtonIconSize,
                floatingButtonFrameSize: floatingButtonFrameSize,
                glassNamespace: glassNamespace,
                onDismiss: onDismiss
            )

            Button(action: onCollapseToolbar) {
                Image(systemName: "chevron.down")
                    .font(.system(size: floatingButtonIconSize, weight: .semibold))
            }
            .frame(width: floatingButtonFrameSize, height: floatingButtonFrameSize)
            .contentShape(.circle)
            .buttonStyle(.plain)
            .glassEffect(in: Circle())
            .accessibilityLabel("Collapse toolbar")
        }
    }
}
