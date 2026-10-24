// WebViewerView.swift
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
import MaruVision
import MaruVisionUICommon
import SwiftUI

public struct WebViewerView: View {
    @ScaledMetric(relativeTo: .body) private var floatingButtonIconSize: CGFloat = 15
    @ScaledMetric(relativeTo: .body) private var floatingButtonFrameSize: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var collapsedAddressMaxWidth: CGFloat = 180

    @State private var viewModel: WebViewerViewModel
    @State private var selectedLookup: WebLookupSelection?
    @State private var suggestionViewModel = WebSearchSuggestionViewModel()
    @State private var isEditingAddress = false
    @State private var addressSnapshot = ""
    @State private var addressSelection: TextSelection?
    @State private var isAddressFocused = false
    @State private var isTabSwitcherPresented = false
    @State private var toolbarTourManager = TourManager()
    @State private var bottomBarHeight: CGFloat = 0
    @State private var statusStrip: WebStatusStrip?
    @State private var stripOccludesBottom = false
    @State private var isLandscape = false
    @Namespace private var glassNamespace

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(YouTubeTranscriptSettings.autoOpenEnabledKey)
    private var transcriptAutoOpenEnabled = YouTubeTranscriptSettings.autoOpenEnabledDefault

    @Environment(\.dismiss) private var dismiss

    public init(initialURL: URL? = nil) {
        _viewModel = State(wrappedValue: WebViewerViewModel(initialURL: initialURL))
    }

    public var body: some View {
        let page = viewModel.page

        ZStack(alignment: .topLeading) {
            if let page {
                WebViewerContentView(
                    viewModel: viewModel,
                    page: page,
                    isEditingAddress: $isEditingAddress,
                    addressSnapshot: addressSnapshot,
                    selectedLookup: $selectedLookup,
                    suggestionViewModel: suggestionViewModel,
                    onNavigateFromNewTabPage: navigateFromNewTabPage,
                    onNavigateFromAddressEditing: navigateFromAddressEditing,
                    onSelectSuggestion: selectSuggestion,
                    bottomBarHeight: bottomBarHeight,
                    filledStatusStrip: fillsStatusStrip ? statusStrip : nil
                )
                .safeAreaBar(edge: .bottom) {
                    WebViewerBottomToolbarView(
                        viewModel: viewModel,
                        addressSelection: $addressSelection,
                        isAddressFocused: $isAddressFocused,
                        isEditingAddress: isEditingAddress,
                        showsBottomRow: !usesSideToolbar,
                        addressDisplayText: addressDisplayText,
                        floatingButtonIconSize: floatingButtonIconSize,
                        floatingButtonFrameSize: floatingButtonFrameSize,
                        collapsedAddressMaxWidth: collapsedAddressMaxWidth,
                        glassNamespace: glassNamespace,
                        onBeginAddressEditing: beginAddressEditing,
                        onCancelAddressEditing: cancelAddressEditing,
                        onSubmitAddress: submitAddress,
                        onShowTabSwitcher: showTabSwitcher,
                        onCollapseToolbar: collapseToolbar,
                        onShowCollapsedControls: showCollapsedControls,
                        onToggleBookmark: toggleBookmark,
                        onNavigateToBookmark: navigateToBookmark,
                        onDismiss: dismissViewer
                    )
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bottomBarHeight = $0 }
                }
                .overlay(alignment: statusStrip?.alignment(occludesBottom: stripOccludesBottom) ?? .bottomTrailing) {
                    if let statusStrip, usesSideToolbar, showsFullControls {
                        sideToolbar(width: statusStrip.width)
                    }
                }
                // The strip's status block sits at the top, so the bar spans the full width like
                // the web content and stays put when the status bar hides. The bar is hosted in
                // its own container, which only hit-tests its laid-out width, so the ignore has
                // to happen out here rather than inside the bar.
                .ignoresSafeArea(edges: fillsStatusStrip ? .horizontal : [])
            } else {
                WebViewerSessionLoadingView()
            }
        }
        .onGeometryChange(for: WebStatusStrip?.self) { WebStatusStrip(safeAreaInsets: $0.safeAreaInsets) } action: { strip in
            // Hiding the status bar on the inner display also drops its inset, so a nil reading
            // while hidden would unhide it again. Nothing else turns a Duo into another device.
            if let strip {
                statusStrip = strip
            }
        }
        .onGeometryChange(for: Bool.self) { $0.size.width > $0.size.height } action: { isLandscape = $0 }
        // Only while the status bar is in the strip: in portrait it is at the top and feeds
        // WebKit's top inset, so hiding it there would reflow the page.
        .statusBarHidden(fillsStatusStrip && isLandscape && !viewModel.overlayState.shouldShowToolbars)
        .overlay(alignment: .top) {
            if let page {
                WebViewerLoadingProgressView(page: page)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.overlayState)
        .animation(.easeInOut(duration: 0.25), value: viewModel.readingModeEnabled)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isShowingNewTabPage)
        .animation(.easeInOut(duration: 0.25), value: isEditingAddress)
        .task(handleInitialTask)
        .task(id: page?.webView) {
            guard let page else { return }
            while !Task.isCancelled {
                await viewModel.autoOpenTranscriptIfPlaying(on: page, enabled: transcriptAutoOpenEnabled) {
                    transcriptAutoOpenEnabled && scenePhase == .active && !isTabSwitcherPresented && selectedLookup == nil && !isEditingAddress
                }
                do {
                    try await Task.sleep(for: .milliseconds(500))
                } catch {
                    return
                }
            }
        }
        .onChange(of: viewModel.page?.url, handlePageURLChange)
        .onChange(of: viewModel.page?.faviconData, handlePageFaviconChange)
        .onChange(of: viewModel.dismissViewerRequestID, handleDismissViewerRequestChange)
        .onChange(of: viewModel.readingModeEnabled, handleReadingModeChange)
        .onChange(of: isAddressFocused, handleAddressFocusChange)
        .onChange(of: viewModel.addressBarText, handleAddressBarTextChange)
        .sheet(item: $selectedLookup) { selection in
            WebViewerDictionarySheetView(
                searchText: selection.text,
                contextValues: selection.contextValues,
                accessibilityIdentifier: "web.dictionarySheet",
                onDismiss: clearSelectedLookup
            )
        }
        .sheet(item: editMenuSelectionBinding) { selection in
            let text = selection.text
            WebViewerDictionarySheetView(
                searchText: Task { text },
                contextValues: selection.contextValues,
                accessibilityIdentifier: "web.editMenuDictionarySheet",
                onDismiss: clearEditMenuSelection
            )
        }
        .toolbarVisibility(.hidden, for: .tabBar)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .tourOverlay(manager: toolbarTourManager)
        .sheet(isPresented: $isTabSwitcherPresented) {
            WebViewerTabSwitcherSheet(
                tabs: viewModel.tabSummaries,
                selectedTabID: viewModel.selectedTabID,
                onSelect: selectTab,
                onClose: closeTab,
                onMove: moveTabs,
                onAddTab: addTab
            )
        }
        .onAppear(perform: handleAppear)
        .onDisappear(perform: viewModel.tearDown)
    }

    /// Outer display: the strip is fully reserved and the system tab bar lives there, so the
    /// secondary toolbar row does too, like Safari.
    private var usesSideToolbar: Bool {
        statusStrip != nil && horizontalSizeClass == .compact
    }

    /// Inner display: only the status block at the top of the strip is occluded, so web content
    /// gets the full width and the status bar hides with the toolbars, like Safari.
    private var fillsStatusStrip: Bool {
        statusStrip != nil && horizontalSizeClass == .regular
    }

    private var showsFullControls: Bool {
        viewModel.overlayState.shouldShowToolbars && !viewModel.readingModeEnabled && !isEditingAddress
    }

    /// The bottom row stacked in the strip, sharing the bottom bar's baseline unless the camera
    /// and status block are down there, in which case it hangs from the top instead.
    private func sideToolbar(width: CGFloat) -> some View {
        let alignment = statusStrip?.alignment(occludesBottom: stripOccludesBottom) ?? .bottomTrailing
        return GlassEffectContainer(spacing: 10) {
            WebViewerBottomRowView(
                axis: .vertical,
                canGoBack: viewModel.page?.canGoBack == true,
                canGoForward: viewModel.page?.canGoForward == true,
                isBookmarked: viewModel.isBookmarked,
                bookmarks: viewModel.bookmarks,
                tabCount: viewModel.tabs.count,
                floatingButtonIconSize: floatingButtonIconSize,
                floatingButtonFrameSize: floatingButtonFrameSize,
                glassNamespace: glassNamespace,
                onGoBack: viewModel.goBack,
                onGoForward: viewModel.goForward,
                onToggleBookmark: toggleBookmark,
                onNavigateToBookmark: navigateToBookmark,
                onShowTabSwitcher: showTabSwitcher,
                onCollapseToolbar: collapseToolbar,
                onDismiss: dismissViewer
            )
        }
        .frame(width: width)
        .frame(maxHeight: .infinity, alignment: alignment)
        .background { WebStripOcclusionProbe { stripOccludesBottom = $0 } }
        .frame(maxWidth: .infinity, alignment: alignment)
        .ignoresSafeArea(edges: .horizontal)
    }

    private var editMenuSelectionBinding: Binding<WebTextSelection?> {
        Binding(
            get: { viewModel.editMenuSelection },
            set: { viewModel.editMenuSelection = $0 }
        )
    }

    private var addressDisplayText: String {
        if let host = viewModel.page?.url?.host, !host.isEmpty {
            return host
        }

        let trimmed = viewModel.addressBarText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }

        return WebStrings.webViewer()
    }

    private func handleInitialTask() async {
        await viewModel.prepareSessionIfNeeded()
        guard WebViewerViewModel.isScreenshotMode else { return }
        try? await Task.sleep(for: .seconds(5))
        viewModel.triggerScreenshotDictionaryLookup()
    }

    private func handlePageURLChange(_: URL?, _ newValue: URL?) {
        if !isEditingAddress {
            viewModel.updateAddressBar(from: newValue)
        }
        viewModel.refreshBookmarkState()
    }

    private func handlePageFaviconChange(_: Data?, _: Data?) {
        viewModel.refreshBookmarkState()
    }

    private func handleDismissViewerRequestChange(_: UUID?, _ newValue: UUID?) {
        guard newValue != nil else { return }
        dismiss()
    }

    private func handleReadingModeChange(_: Bool, _ isEnabled: Bool) {
        if !isEnabled {
            viewModel.overlayState = viewModel.toolbarCollapsedByUser ? .none : .showingToolbars
            viewModel.ocrViewModel.reset()
            viewModel.showBoundingBoxes = false
        }
    }

    private func handleAddressFocusChange(_: Bool, _ newValue: Bool) {
        viewModel.setAddressBarEditing(newValue)

        if isEditingAddress != newValue {
            isEditingAddress = newValue
        }

        if newValue, !viewModel.addressBarText.isEmpty {
            // Defer selection until after focus change propagates to TextField.
            Task { @MainActor in
                addressSelection = TextSelection(
                    range: viewModel.addressBarText.startIndex ..< viewModel.addressBarText.endIndex
                )
            }
        }

        if !newValue {
            suggestionViewModel.cancel()
        }
    }

    private func handleAddressBarTextChange(_: String, _ newValue: String) {
        if isEditingAddress, newValue != addressSnapshot {
            suggestionViewModel.updateQuery(newValue)
        }
    }

    private func handleAppear() {
        if toolbarTourManager.startIfNeeded(WebViewerToolbarTour.self) {
            viewModel.overlayState = .showingToolbars
        }
    }

    private func clearSelectedLookup() {
        selectedLookup = nil
    }

    private func clearEditMenuSelection() {
        viewModel.editMenuSelection = nil
    }

    private func showTabSwitcher() {
        isTabSwitcherPresented = true
    }

    private func collapseToolbar() {
        withAnimation(.easeInOut(duration: 0.25)) {
            viewModel.collapseToolbar()
        }
    }

    private func showCollapsedControls() {
        withAnimation(.easeInOut(duration: 0.25)) {
            viewModel.expandToolbar()
        }
    }

    private func toggleBookmark() {
        viewModel.toggleBookmark()
    }

    private func navigateToBookmark(_ url: URL) {
        viewModel.navigate(to: url)
    }

    private func dismissViewer() {
        dismiss()
    }

    private func selectTab(_ tabID: UUID) {
        viewModel.switchToTab(id: tabID)
        isTabSwitcherPresented = false
    }

    private func closeTab(_ tabID: UUID) {
        viewModel.closeTab(id: tabID)
    }

    private func moveTabs(from source: IndexSet, to destination: Int) {
        viewModel.moveTabs(from: source, to: destination)
    }

    private func addTab() {
        viewModel.addTab()
        isTabSwitcherPresented = false
    }

    private func beginAddressEditing() {
        withAnimation(.easeInOut(duration: 0.25)) {
            viewModel.setAddressBarEditing(true)
        }
        addressSnapshot = viewModel.addressBarText
        isEditingAddress = true
        isAddressFocused = true
    }

    private func cancelAddressEditing() {
        viewModel.addressBarText = addressSnapshot
        suggestionViewModel.cancel()
        isAddressFocused = false
    }

    private func submitAddress() {
        suggestionViewModel.cancel()
        viewModel.navigate(to: viewModel.addressBarText)
        isAddressFocused = false
    }

    private func selectSuggestion(_ suggestion: String) {
        viewModel.addressBarText = suggestion
        submitAddress()
    }

    private func navigateFromNewTabPage(to url: URL) {
        viewModel.navigate(to: url)
    }

    private func navigateFromAddressEditing(to url: URL) {
        viewModel.navigate(to: url)
        isAddressFocused = false
    }
}
