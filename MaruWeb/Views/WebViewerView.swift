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
import WebKit

public struct WebViewerView: View {
    @ScaledMetric(relativeTo: .body) private var floatingButtonIconSize: CGFloat = 15
    @ScaledMetric(relativeTo: .body) private var floatingButtonFrameSize: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var collapsedAddressMaxWidth: CGFloat = 180

    @State private var viewModel: WebViewerViewModel
    @State private var selectedLookup: WebLookupSelection?
    @State private var searchSheetViewModel = DictionarySearchViewModel(resultState: .searching)
    @State private var suggestionViewModel = WebSearchSuggestionViewModel()
    @State private var isEditingAddress = false
    @State private var addressSnapshot = ""
    @State private var addressSelection: TextSelection?
    @State private var isAddressFocused = false
    @State private var isTabSwitcherPresented = false
    @State private var toolbarTourManager = TourManager()
    @Namespace private var glassNamespace

    @Environment(\.dismiss) private var dismiss

    public init(initialURL: URL? = nil) {
        _viewModel = State(wrappedValue: WebViewerViewModel(initialURL: initialURL))
    }

    public var body: some View {
        let page = viewModel.page

        ZStack(alignment: .topLeading) {
            if let page {
                webContent(for: page)
                    .safeAreaBar(edge: .bottom) {
                        bottomControlsOverlay
                    }
            } else {
                webSessionLoadingView
            }
        }
        .overlay(alignment: .top) {
            if let page {
                loadingProgressOverlay(for: page)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.overlayState)
        .animation(.easeInOut(duration: 0.25), value: viewModel.readingModeEnabled)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isShowingNewTabPage)
        .animation(.easeInOut(duration: 0.25), value: isEditingAddress)
        .task {
            await viewModel.prepareSessionIfNeeded()
        }
        .onChange(of: viewModel.page?.url) { _, newValue in
            if !isEditingAddress {
                viewModel.updateAddressBar(from: newValue)
            }
            viewModel.refreshBookmarkState()
        }
        .onChange(of: viewModel.page?.faviconData) { _, _ in
            viewModel.refreshBookmarkState()
        }
        .onChange(of: viewModel.dismissViewerRequestID) { _, newValue in
            guard newValue != nil else { return }
            dismiss()
        }
        .onChange(of: viewModel.readingModeEnabled) { _, isEnabled in
            if !isEnabled {
                viewModel.overlayState = .showingToolbars
                viewModel.ocrViewModel.reset()
                viewModel.showBoundingBoxes = false
            }
        }
        .onChange(of: isAddressFocused) { _, newValue in
            if isEditingAddress != newValue {
                isEditingAddress = newValue
            }
            if newValue, viewModel.overlayState != .showingToolbars {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.overlayState = .showingToolbars
                }
            }
            if newValue, !viewModel.addressBarText.isEmpty {
                // Defer selection until after focus change propagates to TextField
                Task { @MainActor in
                    addressSelection = TextSelection(range: viewModel.addressBarText.startIndex ..< viewModel.addressBarText.endIndex)
                }
            }
            if !newValue {
                suggestionViewModel.cancel()
            }
        }
        .onChange(of: viewModel.addressBarText) { _, newValue in
            if isEditingAddress, newValue != addressSnapshot {
                suggestionViewModel.updateQuery(newValue)
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
        .sheet(
            item: Binding(
                get: { viewModel.editMenuSelection },
                set: { viewModel.editMenuSelection = $0 }
            )
        ) { selection in
            NavigationStack {
                DictionarySearchView()
                    .environment(searchSheetViewModel)
                    .navigationTitle("Dictionary")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                viewModel.editMenuSelection = nil
                            }
                        }
                    }
            }
            .onAppear {
                searchSheetViewModel.performSearch(
                    selection.text,
                    contextValues: selection.contextValues
                )
            }
            .presentationDetents([.medium, .large])
        }
        .toolbarVisibility(.hidden, for: .tabBar)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .tourOverlay(manager: toolbarTourManager)
        .sheet(isPresented: $isTabSwitcherPresented) {
            TabSwitcherSheet(
                tabs: viewModel.tabSummaries,
                selectedTabID: viewModel.selectedTabID,
                onSelect: { tabID in
                    viewModel.switchToTab(id: tabID)
                    isTabSwitcherPresented = false
                },
                onClose: { tabID in
                    viewModel.closeTab(id: tabID)
                },
                onMove: { source, destination in
                    viewModel.moveTabs(from: source, to: destination)
                },
                onAddTab: {
                    viewModel.addTab()
                    isTabSwitcherPresented = false
                }
            )
        }
        .onAppear {
            if toolbarTourManager.startIfNeeded(WebViewerToolbarTour.self) {
                viewModel.overlayState = .showingToolbars
            }
        }
    }

    private func webContent(for page: WebBrowserPage) -> some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 1)
            ZStack {
                let model = viewModel
                WebBrowserView(page: page) { [weak model] oldOffset, newOffset in
                    model?.handleScrollOffsetChange(from: oldOffset, to: newOffset)
                }
                .id(page.webView)

                if viewModel.isShowingNewTabPage, !isEditingAddress {
                    NewTabPageView(
                        bookmarks: viewModel.bookmarks,
                        onNavigate: { url in
                            viewModel.navigate(to: url)
                        }
                    )
                    .transition(.opacity)
                }

                if isEditingAddress {
                    addressEditingOverlay
                        .transition(.opacity)
                }

                if viewModel.readingModeEnabled {
                    GeometryReader { geometry in
                        WebReadingModeOverlay(
                            clusters: viewModel.ocrViewModel.clusters,
                            showBoundingBoxes: viewModel.showBoundingBoxes,
                            highlightedCluster: viewModel.highlightedCluster,
                            isProcessing: viewModel.ocrViewModel.isProcessing,
                            onTap: { location, size in
                                Task {
                                    if let selection = await viewModel.lookupCluster(at: location, in: size) {
                                        viewModel.highlightedCluster = selection.cluster
                                        try? await Task.sleep(nanoseconds: 100_000_000)
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            viewModel.exitReadingModeAfterLookupSelection()
                                        }
                                        selectedLookup = selection
                                        viewModel.highlightedCluster = nil
                                    }
                                }
                            }
                        )
                        .task {
                            await viewModel.captureAndRunOCR(viewSize: geometry.size)
                        }
                    }
                }
            }
            Color.clear
                .frame(height: 1)
        }
    }

    private var webSessionLoadingView: some View {
        ProgressView("Preparing Web Viewer")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background)
    }

    private var bottomControlsOverlay: some View {
        GlassEffectContainer(spacing: 10) {
            ZStack {
                if shouldShowFloatingReadingModeButton {
                    collapsedAddressCapsule
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                if shouldShowFullControls {
                    bottomControlsRow
                }

                // Transparent placeholder that maintains the single-row toolbar height when
                // reading mode hides the full controls, preventing a safeAreaBar layout
                // shift that would misalign OCR bounding boxes.
                if viewModel.readingModeEnabled, viewModel.overlayState.shouldShowToolbars {
                    readingModeToolbarPlaceholder
                }

                if shouldShowReadingModeExitButton {
                    readingModeControlsRow
                } else if shouldShowFloatingReadingModeButton {
                    readingModeButton
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .padding(.top, 5)
    }

    private var readingModeToolbarPlaceholder: some View {
        Color.clear.frame(height: floatingButtonFrameSize)
            .accessibilityHidden(true)
    }

    private var bottomControlsRow: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if canGoBack || canGoForward {
                navigationCluster
            }

            addressBarCapsule
                .frame(maxWidth: .infinity)

            tabsButton
            readingModeButton
            overflowMenuButton
        }
    }

    private var navigationCluster: some View {
        HStack(spacing: 0) {
            if canGoBack {
                navigationButton(
                    systemName: "chevron.backward",
                    accessibilityLabel: "Back",
                    action: viewModel.goBack
                )
            }

            if canGoBack, canGoForward {
                Divider()
                    .frame(height: floatingButtonFrameSize - 12)
            }

            if canGoForward {
                navigationButton(
                    systemName: "chevron.forward",
                    accessibilityLabel: "Forward",
                    action: viewModel.goForward
                )
            }
        }
        .padding(.horizontal, 2)
        .glassEffect(in: Capsule())
        .glassEffectID("navCluster", in: glassNamespace)
        .glassEffectTransition(.matchedGeometry)
    }

    private var addressBarCapsule: some View {
        AddressBarCapsuleView(
            addressText: $viewModel.addressBarText,
            addressSelection: $addressSelection,
            shouldFocus: $isAddressFocused,
            isEditingAddress: isEditingAddress,
            displayText: addressDisplayText,
            namespace: glassNamespace,
            iconSize: floatingButtonIconSize,
            onBeginEditing: beginAddressEditing,
            onSubmit: submitAddress
        )
        .tourAnchor(WebViewerToolbarTourAnchor.addressBar)
    }

    private var collapsedAddressCapsule: some View {
        CollapsedAddressCapsuleView(
            displayText: addressDisplayText,
            namespace: glassNamespace,
            iconSize: floatingButtonIconSize,
            maxWidth: collapsedAddressMaxWidth,
            onTap: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.overlayState = .showingToolbars
                }
            }
        )
    }

    private var overflowMenuButton: some View {
        Menu {
            reloadOverflowMenuItem
            bookmarksOverflowSubmenu
            Divider()
            exitOverflowMenuItem
        } label: {
            overflowMenuLabel
        }
        .frame(width: floatingButtonFrameSize, height: floatingButtonFrameSize)
        .contentShape(.circle)
        .buttonStyle(.plain)
        .glassEffect(in: Circle())
        .glassEffectID("overflow", in: glassNamespace)
        .glassEffectTransition(GlassEffectTransition.matchedGeometry)
        .accessibilityLabel("More Actions")
        .tourAnchor(WebViewerToolbarTourAnchor.bookmarkButton)
    }

    private var reloadOverflowMenuItem: some View {
        Button {
            if viewModel.page?.isLoading == true {
                viewModel.stopLoading()
            } else {
                viewModel.reload()
            }
        } label: {
            Label(
                viewModel.page?.isLoading == true ? "Stop Loading" : "Reload",
                systemImage: viewModel.page?.isLoading == true ? "xmark" : "arrow.clockwise"
            )
        }
    }

    private var bookmarksOverflowSubmenu: some View {
        Menu {
            if viewModel.isBookmarked {
                Button(role: .destructive) {
                    viewModel.removeBookmarkForCurrentPage()
                } label: {
                    Label("Remove Bookmark", systemImage: "bookmark.slash")
                }
            } else {
                Button {
                    viewModel.addBookmarkForCurrentPage()
                } label: {
                    Label("Add Bookmark", systemImage: "bookmark.fill")
                }
            }

            if !viewModel.bookmarks.isEmpty {
                Section("Saved Bookmarks") {
                    ForEach(viewModel.bookmarks, id: \.id) { bookmark in
                        Button {
                            viewModel.navigate(to: bookmark.url)
                        } label: {
                            HStack(spacing: 8) {
                                BookmarkFaviconView(data: bookmark.favicon, size: 16)
                                Text(bookmark.title)
                            }
                        }
                    }
                }
            }
        } label: {
            Label("Bookmarks", systemImage: viewModel.isBookmarked ? "bookmark.fill" : "bookmark")
        }
    }

    private var exitOverflowMenuItem: some View {
        Button {
            dismiss()
        } label: {
            Label("Exit Web Viewer", systemImage: "xmark")
        }
    }

    private var overflowMenuLabel: some View {
        ZStack {
            Image(systemName: "ellipsis")
                .font(.system(size: floatingButtonIconSize, weight: .semibold))

            Color.clear
                .allowsHitTesting(false)
                .tourAnchor(WebViewerToolbarTourAnchor.dismissButton)
        }
    }

    private var readingModeButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                isAddressFocused = false
                viewModel.readingModeEnabled = true
            }
        } label: {
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
    }

    private var readingModeExitButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                viewModel.readingModeEnabled = false
                viewModel.overlayState = .showingToolbars
            }
        } label: {
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

    private var readingModeControlsRow: some View {
        HStack(spacing: 12) {
            Spacer()
            boundingBoxToggleButton
            readingModeExitButton
        }
    }

    private var boundingBoxToggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.showBoundingBoxes.toggle()
            }
        } label: {
            Image(systemName: viewModel.showBoundingBoxes ? "text.viewfinder" : "viewfinder")
                .font(.system(size: floatingButtonIconSize, weight: .semibold))
        }
        .frame(width: floatingButtonFrameSize, height: floatingButtonFrameSize)
        .contentShape(.circle)
        .buttonStyle(.plain)
        .glassEffect(in: Circle())
        .accessibilityLabel(viewModel.showBoundingBoxes ? "Hide text regions" : "Show text regions")
    }

    private var tabsButton: some View {
        Button {
            isTabSwitcherPresented = true
        } label: {
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
    }

    private func loadingProgressOverlay(for page: WebBrowserPage) -> some View {
        Group {
            if page.isLoading {
                ProgressView(value: page.estimatedProgress)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var addressDisplayText: String {
        if let host = viewModel.page?.url?.host, !host.isEmpty {
            return host
        }
        let trimmed = viewModel.addressBarText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return "Web Viewer"
    }

    private var canGoBack: Bool {
        viewModel.page?.canGoBack == true
    }

    private var canGoForward: Bool {
        viewModel.page?.canGoForward == true
    }

    private var shouldShowFullControls: Bool {
        viewModel.overlayState.shouldShowToolbars && !viewModel.readingModeEnabled
    }

    private var shouldShowFloatingReadingModeButton: Bool {
        !viewModel.overlayState.shouldShowToolbars && !viewModel.readingModeEnabled
    }

    private var shouldShowReadingModeExitButton: Bool {
        viewModel.readingModeEnabled
    }

    private func navigationButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: floatingButtonIconSize, weight: .semibold))
        }
        .frame(width: floatingButtonFrameSize - 4, height: floatingButtonFrameSize)
        .contentShape(.rect)
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func beginAddressEditing() {
        withAnimation(.easeInOut(duration: 0.25)) {
            viewModel.overlayState = .showingToolbars
        }
        addressSnapshot = viewModel.addressBarText
        isEditingAddress = true
        isAddressFocused = true
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

    private var isAddressTextDirty: Bool {
        viewModel.addressBarText != addressSnapshot
    }

    @ViewBuilder
    private var addressEditingOverlay: some View {
        if isAddressTextDirty {
            WebSearchSuggestionsView(
                suggestions: suggestionViewModel.suggestions,
                isLoading: suggestionViewModel.isLoading,
                onSelect: selectSuggestion
            )
        } else {
            NewTabPageView(
                bookmarks: viewModel.bookmarks,
                onNavigate: { url in
                    viewModel.navigate(to: url)
                    isAddressFocused = false
                }
            )
        }
    }
}

private struct AddressBarCapsuleView: View {
    @Binding var addressText: String
    @Binding var addressSelection: TextSelection?
    @Binding var shouldFocus: Bool
    let isEditingAddress: Bool
    let displayText: String
    let namespace: Namespace.ID
    let iconSize: CGFloat
    let onBeginEditing: () -> Void
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.system(size: iconSize - 2, weight: .semibold))

            ZStack(alignment: .leading) {
                if !isEditingAddress {
                    Text(displayText)
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                        .onTapGesture(perform: onBeginEditing)
                }

                TextField("Search or enter URL", text: $addressText, selection: $addressSelection)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .focused($isFocused)
                    .opacity(isEditingAddress ? 1 : 0)
                    .disabled(!isEditingAddress)
                    .onSubmit(onSubmit)
                    .onChange(of: isFocused) { _, newValue in
                        if shouldFocus != newValue {
                            shouldFocus = newValue
                        }
                    }
                    .onChange(of: shouldFocus) { _, newValue in
                        if isFocused != newValue {
                            isFocused = newValue
                        }
                    }
            }
            .padding(.vertical, 10)
        }
        .padding(.horizontal, 14)
        .glassEffect(in: Capsule())
        .glassEffectID("address", in: namespace)
        .glassEffectTransition(GlassEffectTransition.matchedGeometry)
    }
}

private struct CollapsedAddressCapsuleView: View {
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
            .frame(maxWidth: maxWidth)
        }
        .buttonStyle(.plain)
        .glassEffect(in: Capsule())
        .glassEffectID("address", in: namespace)
        .glassEffectTransition(GlassEffectTransition.matchedGeometry)
        .accessibilityLabel("Show Controls")
    }
}

private struct TabSwitcherSheet: View {
    let tabs: [WebTabSummary]
    let selectedTabID: UUID?
    let onSelect: (UUID) -> Void
    let onClose: (UUID) -> Void
    let onMove: (IndexSet, Int) -> Void
    let onAddTab: () -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(tabs) { tab in
                    TabSwitcherRow(
                        tab: tab,
                        isSelected: tab.id == selectedTabID,
                        onSelect: { onSelect(tab.id) },
                        onClose: { onClose(tab.id) }
                    )
                }
                .onMove(perform: onMove)
            }
            .navigationTitle("Tabs")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("New Tab", action: onAddTab)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
    }
}

private struct TabSwitcherRow: View {
    let tab: WebTabSummary
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 10) {
                    Image(systemName: tab.isLoading ? "arrow.trianglehead.2.clockwise.rotate.90" : "globe")
                        .symbolEffect(.rotate, isActive: tab.isLoading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tab.title)
                            .font(.body)
                            .lineLimit(1)
                        Text(tab.host)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(role: .destructive, action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close Tab")
        }
        .padding(.vertical, 2)
    }
}
