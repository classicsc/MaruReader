// WebViewerView.swift
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

import MaruDictionaryUICommon
import MaruVision
import MaruVisionUICommon
import SwiftUI
import WebKit

public struct WebViewerView: View {
    @ScaledMetric(relativeTo: .body) private var floatingButtonIconSize: CGFloat = 15
    @ScaledMetric(relativeTo: .body) private var floatingButtonFrameSize: CGFloat = 40

    @State private var viewModel: WebViewerViewModel
    @State private var selectedLookup: WebLookupSelection?
    @State private var searchSheetViewModel = DictionarySearchViewModel(resultState: .searching)
    @State private var isEditingAddress = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pixelLength) var onePixel

    public init(initialURL: URL? = nil) {
        _viewModel = State(wrappedValue: WebViewerViewModel(initialURL: initialURL))
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // Main web content area
            VStack(spacing: 0) {
                ZStack {
                    WebView(viewModel.page)
                        .webViewOnScrollGeometryChange(for: CGFloat.self) { geometry in
                            geometry.contentOffset.y
                        } action: { oldOffset, newOffset in
                            viewModel.handleScrollOffsetChange(from: oldOffset, to: newOffset)
                        }
                        .padding(.top, onePixel)
                        .ignoresSafeArea(edges: .bottom)

                    if viewModel.readingModeEnabled {
                        WebReadingModeOverlay(
                            isProcessing: viewModel.ocrViewModel.isProcessing,
                            pagingAxis: viewModel.pagingAxis,
                            pagingBehavior: viewModel.pagingBehavior,
                            onTap: { location, size in
                                Task {
                                    if let selection = await viewModel.lookupCluster(at: location, in: size) {
                                        selectedLookup = selection
                                    }
                                }
                            },
                            onPageAction: { axis, behavior, direction in
                                viewModel.performPagingAction(axis: axis, behavior: behavior, direction: direction)
                            }
                        )
                        readingModeToolbarToggleButton
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(.trailing, 16)
                            .padding(.top, 16)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.overlayState.shouldShowToolbars {
                bottomToolbarOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                bottomToolbarOverlay.hidden()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.overlayState)
        .onAppear {
            viewModel.loadInitialURLIfNeeded()
        }
        .onChange(of: viewModel.page.url) { _, newValue in
            if !isEditingAddress {
                viewModel.updateAddressBar(from: newValue)
            }
            viewModel.refreshBookmarkState()
        }
        .onChange(of: viewModel.readingModeEnabled) { _, isEnabled in
            // Auto-hide toolbar when entering reading mode
            if isEnabled {
                viewModel.overlayState = .none
            }
        }
        .sheet(item: $selectedLookup) { selection in
            NavigationStack {
                DictionarySearchView()
                    .environment(searchSheetViewModel)
                    .navigationTitle("Dictionary")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                selectedLookup = nil
                            }
                        }
                    }
            }
            .onAppear {
                searchSheetViewModel.performSearch(
                    selection.cluster.transcript,
                    contextValues: selection.contextValues
                )
            }
            .presentationDetents([.medium, .large])
        }
        .toolbarVisibility(.hidden, for: .tabBar)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
    }

    private var bottomToolbarOverlay: some View {
        WebToolbarView(
            addressText: $viewModel.addressBarText,
            isLoading: viewModel.page.isLoading,
            estimatedProgress: viewModel.page.estimatedProgress,
            canGoBack: !viewModel.page.backForwardList.backList.isEmpty,
            canGoForward: !viewModel.page.backForwardList.forwardList.isEmpty,
            isReadingModeEnabled: viewModel.readingModeEnabled,
            pagingAxis: viewModel.pagingAxis,
            pagingBehavior: viewModel.pagingBehavior,
            isBookmarked: viewModel.isBookmarked,
            onAddressEditingChanged: { isEditing in
                isEditingAddress = isEditing
            },
            onSubmitAddress: {
                viewModel.navigate(to: viewModel.addressBarText)
            },
            onBack: {
                viewModel.goBack()
            },
            onForward: {
                viewModel.goForward()
            },
            onReload: {
                viewModel.reload()
            },
            onStopLoading: {
                viewModel.stopLoading()
            },
            onBookmark: {
                viewModel.toggleBookmark()
            },
            onToggleReadingMode: {
                viewModel.readingModeEnabled.toggle()
            },
            onTogglePagingAxis: {
                viewModel.togglePagingAxis()
            },
            onTogglePagingBehavior: {
                viewModel.togglePagingBehavior()
            },
            onExit: {
                dismiss()
            }
        )
        .foregroundStyle(toolbarForegroundColor(isPrimary: true))
        .padding(.bottom, 12)
    }

    private var readingModeToolbarToggleButton: some View {
        Button {
            viewModel.toggleOverlay()
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: floatingButtonIconSize, weight: .semibold))
                .foregroundStyle(toolbarForegroundColor(isPrimary: true))
                .frame(width: floatingButtonFrameSize, height: floatingButtonFrameSize)
        }
        .glassEffect(in: .circle)
        .accessibilityLabel("Toggle Toolbar")
    }

    private var displayTitle: String {
        let title = viewModel.page.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            return title
        }
        if let host = viewModel.page.url?.host, !host.isEmpty {
            return host
        }
        return "Web Viewer"
    }

    private var interfaceForegroundColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var toolbarSecondaryColor: Color {
        if colorScheme == .dark {
            return Color(
                red: Double(0x98) / 255.0,
                green: Double(0x98) / 255.0,
                blue: Double(0x9D) / 255.0
            )
        }
        return Color(
            red: Double(0x6C) / 255.0,
            green: Double(0x6C) / 255.0,
            blue: Double(0x70) / 255.0
        )
    }

    private func toolbarForegroundColor(isPrimary: Bool) -> Color {
        isPrimary ? interfaceForegroundColor : interfaceForegroundColor.opacity(0.6)
    }
}
