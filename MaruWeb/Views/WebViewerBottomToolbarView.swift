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
    let onShowCollapsedControls: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        let canGoBack = viewModel.page?.canGoBack == true
        let canGoForward = viewModel.page?.canGoForward == true
        let shouldShowFullControls = viewModel.overlayState.shouldShowToolbars && !viewModel.readingModeEnabled
        let shouldShowFloatingReadingModeButton = !viewModel.overlayState.shouldShowToolbars && !viewModel.readingModeEnabled

        GlassEffectContainer(spacing: 10) {
            ZStack {
                if shouldShowFloatingReadingModeButton {
                    WebViewerCollapsedAddressCapsuleView(
                        displayText: addressDisplayText,
                        namespace: glassNamespace,
                        iconSize: floatingButtonIconSize,
                        maxWidth: collapsedAddressMaxWidth,
                        onTap: onShowCollapsedControls
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                if shouldShowFullControls {
                    HStack(alignment: .bottom, spacing: 12) {
                        if !isEditingAddress, canGoBack || canGoForward {
                            WebViewerNavigationClusterView(
                                canGoBack: canGoBack,
                                canGoForward: canGoForward,
                                iconSize: floatingButtonIconSize,
                                frameSize: floatingButtonFrameSize,
                                namespace: glassNamespace,
                                onGoBack: viewModel.goBack,
                                onGoForward: viewModel.goForward
                            )
                        }

                        WebViewerAddressBarCapsuleView(
                            addressText: $viewModel.addressBarText,
                            addressSelection: $addressSelection,
                            shouldFocus: $isAddressFocused,
                            isEditingAddress: isEditingAddress,
                            displayText: addressDisplayText,
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
                            Button(action: onShowTabSwitcher) {
                                Image(systemName: "square.on.square")
                                    .font(.system(size: floatingButtonIconSize, weight: .semibold))
                            }
                            .frame(width: floatingButtonFrameSize, height: floatingButtonFrameSize)
                            .contentShape(.circle)
                            .buttonStyle(.plain)
                            .glassEffect(in: Circle())
                            .overlay(alignment: .topTrailing) {
                                Text("\(viewModel.tabs.count)")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(.thinMaterial, in: Capsule())
                                    .offset(x: 8, y: -8)
                            }
                            .accessibilityLabel("Tabs")
                            .accessibilityValue("\(viewModel.tabs.count)")

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
                            .tourAnchor(WebViewerToolbarTourAnchor.readingModeButton)

                            WebViewerOverflowMenuButton(
                                viewModel: viewModel,
                                floatingButtonIconSize: floatingButtonIconSize,
                                floatingButtonFrameSize: floatingButtonFrameSize,
                                glassNamespace: glassNamespace,
                                onDismiss: onDismiss
                            )
                            .tourAnchor(WebViewerToolbarTourAnchor.bookmarkButton)
                        }
                    }
                }

                // Maintain toolbar height when reading mode hides the regular controls.
                if viewModel.readingModeEnabled, viewModel.overlayState.shouldShowToolbars {
                    Color.clear
                        .frame(height: floatingButtonFrameSize)
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
                    .frame(maxWidth: .infinity, alignment: .trailing)
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
