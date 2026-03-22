// WebViewerBottomToolbarView.swift
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
import Observation
import SwiftUI

struct WebViewerBottomToolbarView: View {
    @Bindable var viewModel: WebViewerViewModel
    @Binding var addressSelection: TextSelection?
    @Binding var isAddressFocused: Bool
    let isEditingAddress: Bool
    let addressDisplayText: String
    let floatingButtonIconSize: CGFloat
    let floatingButtonFrameSize: CGFloat
    let collapsedAddressMaxWidth: CGFloat
    let glassNamespace: Namespace.ID
    let onBeginAddressEditing: () -> Void
    let onCancelAddressEditing: () -> Void
    let onSubmitAddress: () -> Void
    let onShowTabSwitcher: () -> Void
    let onCollapseToolbar: () -> Void
    let onShowCollapsedControls: () -> Void
    let onToggleBookmark: () -> Void
    let onNavigateToBookmark: (URL) -> Void
    let onDismiss: () -> Void

    var body: some View {
        let canGoBack = viewModel.page?.canGoBack == true
        let canGoForward = viewModel.page?.canGoForward == true
        let isLoading = viewModel.page?.isLoading == true
        let shouldShowFullControls = viewModel.overlayState.shouldShowToolbars && !viewModel.readingModeEnabled
        let shouldShowFloatingReadingModeButton = !viewModel.overlayState.shouldShowToolbars && !viewModel.readingModeEnabled

        GlassEffectContainer(spacing: 10) {
            ZStack {
                if shouldShowFloatingReadingModeButton {
                    WebViewerCollapsedAddressCapsuleView(
                        displayText: addressDisplayText,
                        namespace: glassNamespace,
                        maxWidth: collapsedAddressMaxWidth,
                        onTap: onShowCollapsedControls
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                if shouldShowFullControls {
                    VStack(spacing: 8) {
                        WebViewerTopRowView(
                            addressText: $viewModel.addressBarText,
                            addressSelection: $addressSelection,
                            isAddressFocused: $isAddressFocused,
                            isEditingAddress: isEditingAddress,
                            isLoading: isLoading,
                            displayText: addressDisplayText,
                            floatingButtonIconSize: floatingButtonIconSize,
                            floatingButtonFrameSize: floatingButtonFrameSize,
                            glassNamespace: glassNamespace,
                            onBeginAddressEditing: onBeginAddressEditing,
                            onCancelAddressEditing: onCancelAddressEditing,
                            onSubmitAddress: onSubmitAddress,
                            onEnableReadingMode: enableReadingMode,
                            onStopLoading: viewModel.stopLoading,
                            onReload: viewModel.reload
                        )

                        if !isEditingAddress {
                            WebViewerBottomRowView(
                                canGoBack: canGoBack,
                                canGoForward: canGoForward,
                                isBookmarked: viewModel.isBookmarked,
                                bookmarks: viewModel.bookmarks,
                                tabCount: viewModel.tabs.count,
                                floatingButtonIconSize: floatingButtonIconSize,
                                floatingButtonFrameSize: floatingButtonFrameSize,
                                glassNamespace: glassNamespace,
                                onGoBack: viewModel.goBack,
                                onGoForward: viewModel.goForward,
                                onToggleBookmark: onToggleBookmark,
                                onNavigateToBookmark: onNavigateToBookmark,
                                onShowTabSwitcher: onShowTabSwitcher,
                                onCollapseToolbar: onCollapseToolbar,
                                onDismiss: onDismiss
                            )
                        }
                    }
                }

                // Maintain toolbar height when reading mode hides the regular controls.
                if viewModel.readingModeEnabled, viewModel.overlayState.shouldShowToolbars {
                    Color.clear
                        .frame(height: floatingButtonFrameSize * 2 + 8)
                        .accessibilityHidden(true)
                }

                if viewModel.readingModeEnabled {
                    HStack(spacing: 12) {
                        Spacer()

                        Button(action: toggleBoundingBoxes) {
                            Image(systemName: viewModel.showBoundingBoxes ? "text.viewfinder" : "viewfinder")
                                .font(.system(size: floatingButtonIconSize, weight: .semibold))
                        }
                        .frame(width: floatingButtonFrameSize, height: floatingButtonFrameSize)
                        .contentShape(.circle)
                        .buttonStyle(.plain)
                        .glassEffect(in: Circle())
                        .accessibilityLabel(
                            viewModel.showBoundingBoxes
                                ? Text("Hide text regions")
                                : Text("Show text regions")
                        )

                        Button(action: disableReadingMode) {
                            Image(systemName: "xmark")
                                .font(.system(size: floatingButtonIconSize, weight: .semibold))
                        }
                        .frame(width: floatingButtonFrameSize, height: floatingButtonFrameSize)
                        .contentShape(.circle)
                        .buttonStyle(.plain)
                        .glassEffect(in: Circle())
                        .glassEffectID("readingMode", in: glassNamespace)
                        .glassEffectTransition(GlassEffectTransition.matchedGeometry)
                        .accessibilityLabel("Exit OCR Mode")
                    }
                } else if shouldShowFloatingReadingModeButton {
                    Button(action: enableReadingMode) {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tourAnchor(WebViewerToolbarTourAnchor.readingModeButton)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .padding(.top, 5)
    }

    private func enableReadingMode() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isAddressFocused = false
            viewModel.readingModeEnabled = true
        }
    }

    private func disableReadingMode() {
        withAnimation(.easeInOut(duration: 0.25)) {
            viewModel.readingModeEnabled = false
            viewModel.overlayState = .showingToolbars
        }
    }

    private func toggleBoundingBoxes() {
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.showBoundingBoxes.toggle()
        }
    }
}
