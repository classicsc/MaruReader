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
    @ScaledMetric(relativeTo: .body) private var addressAccessorySize: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var collapsedAddressMaxWidth: CGFloat = 180

    @State private var viewModel: WebViewerViewModel
    @State private var selectedLookup: WebLookupSelection?
    @State private var searchSheetViewModel = DictionarySearchViewModel(resultState: .searching)
    @State private var isEditingAddress = false
    @State private var readingModeMenuExpanded = false
    @State private var addressSelection: TextSelection?
    @State private var isAddressFocused = false
    @Namespace private var glassNamespace

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pixelLength) var onePixel

    public init(initialURL: URL? = nil) {
        _viewModel = State(wrappedValue: WebViewerViewModel(initialURL: initialURL))
    }

    public var body: some View {
        let page = viewModel.page

        ZStack(alignment: .topLeading) {
            if let page {
                webContent(for: page)
            } else {
                webSessionLoadingView
            }

            if page != nil {
                bottomControlsOverlay
            }
        }
        .overlay(alignment: .top) {
            if let page {
                loadingProgressOverlay(for: page)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.overlayState)
        .animation(.easeInOut(duration: 0.25), value: viewModel.readingModeEnabled)
        .animation(.easeInOut(duration: 0.25), value: readingModeMenuExpanded)
        .task {
            await viewModel.prepareSessionIfNeeded()
        }
        .onChange(of: viewModel.page?.url) { _, newValue in
            if !isEditingAddress {
                viewModel.updateAddressBar(from: newValue)
            }
            viewModel.refreshBookmarkState()
        }
        .onChange(of: viewModel.readingModeEnabled) { _, isEnabled in
            if isEnabled {
                viewModel.overlayState = .none
            } else {
                readingModeMenuExpanded = false
                viewModel.overlayState = .showingToolbars
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

    private func webContent(for page: WebPage) -> some View {
        VStack(spacing: 0) {
            ZStack {
                WebView(page)
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
                }
            }
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
                if shouldShowCollapsedAddress {
                    collapsedAddressCapsule
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                if shouldShowFullControls {
                    bottomControlsRow
                }

                if readingModeMenuExpanded {
                    readingModeMenu
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else if shouldShowReadingModeButtonOnly {
                    readingModeButton
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private var bottomControlsRow: some View {
        HStack(alignment: .bottom) {
            dismissButton

            if canGoBack || canGoForward {
                navigationCluster
            }

            Spacer()

            addressCluster

            Spacer()

            readingModeButton
        }
    }

    private var navigationCluster: some View {
        HStack(spacing: 12) {
            if canGoBack {
                navigationButton(
                    systemName: "chevron.backward",
                    accessibilityLabel: "Back",
                    action: viewModel.goBack
                )
                .glassEffectID("navBack", in: glassNamespace)
                .glassEffectTransition(.matchedGeometry)
            }

            if canGoForward {
                navigationButton(
                    systemName: "chevron.forward",
                    accessibilityLabel: "Forward",
                    action: viewModel.goForward
                )
                .glassEffectID("navForward", in: glassNamespace)
                .glassEffectTransition(.matchedGeometry)
            }
        }
    }

    private var addressCluster: some View {
        HStack(spacing: 12) {
            addressBarCapsule
            bookmarkButton
        }
    }

    private var addressBarCapsule: some View {
        AddressBarCapsuleView(
            addressText: $viewModel.addressBarText,
            addressSelection: $addressSelection,
            shouldFocus: $isAddressFocused,
            isEditingAddress: isEditingAddress,
            displayText: addressDisplayText,
            isLoading: viewModel.page?.isLoading ?? false,
            namespace: glassNamespace,
            iconSize: floatingButtonIconSize,
            accessorySize: addressAccessorySize,
            onBeginEditing: beginAddressEditing,
            onSubmit: submitAddress,
            onReload: viewModel.reload,
            onStopLoading: viewModel.stopLoading
        )
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

    private var bookmarkButton: some View {
        let isCurrentLocationBookmarked = viewModel.isBookmarked
        return Menu {
            if isCurrentLocationBookmarked {
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
                Section("Bookmarks") {
                    ForEach(viewModel.bookmarks, id: \.id) { bookmark in
                        Button {
                            viewModel.navigate(to: bookmark.url)
                        } label: {
                            Text(bookmark.title)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: isCurrentLocationBookmarked ? "bookmark.fill" : "bookmark")
                .font(.system(size: floatingButtonIconSize, weight: .semibold))
        }
        .frame(width: floatingButtonFrameSize, height: floatingButtonFrameSize)
        .contentShape(.circle)
        .buttonStyle(.plain)
        .glassEffect(in: Circle())
        .glassEffectID("bookmark", in: glassNamespace)
        .glassEffectTransition(GlassEffectTransition.matchedGeometry)
        .accessibilityLabel("Bookmarks")
    }

    private var readingModeButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                isAddressFocused = false
                viewModel.readingModeEnabled = true
                readingModeMenuExpanded = true
                viewModel.overlayState = .none
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
        .accessibilityLabel(viewModel.readingModeEnabled ? "Reading Mode Options" : "Enable Reading Mode")
    }

    private var readingModeMenu: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Button {
                viewModel.togglePagingBehavior()
            } label: {
                Image(systemName: viewModel.pagingBehavior == .scroll ? "hand.draw" : "keyboard")
                    .font(.system(size: floatingButtonIconSize, weight: .semibold))
            }
            .frame(width: floatingButtonFrameSize, height: floatingButtonFrameSize)
            .contentShape(.circle)
            .buttonStyle(.plain)
            .glassEffect(in: Circle())
            .glassEffectTransition(GlassEffectTransition.materialize)
            .accessibilityLabel(viewModel.pagingBehavior == .scroll ? "Switch to Keypress Paging" : "Switch to Scroll Paging")

            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        readingModeMenuExpanded = false
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
                .glassEffectTransition(GlassEffectTransition.materialize)
                .accessibilityLabel("Exit Reading Mode")

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        readingModeMenuExpanded = false
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: floatingButtonIconSize, weight: .semibold))
                }
                .frame(width: floatingButtonFrameSize, height: floatingButtonFrameSize)
                .contentShape(.circle)
                .buttonStyle(.plain)
                .glassEffect(in: Circle())
                .glassEffectID("readingMode", in: glassNamespace)
                .glassEffectTransition(GlassEffectTransition.matchedGeometry)
                .accessibilityLabel("Collapse Reading Mode Menu")
            }
        }
    }

    private var dismissButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: floatingButtonIconSize, weight: .semibold))
        }
        .frame(width: floatingButtonFrameSize, height: floatingButtonFrameSize)
        .contentShape(.circle)
        .buttonStyle(.plain)
        .glassEffect(in: Circle())
        .accessibilityLabel("Exit Web Viewer")
    }

    private func loadingProgressOverlay(for page: WebPage) -> some View {
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
        viewModel.page?.backForwardList.backList.isEmpty == false
    }

    private var canGoForward: Bool {
        viewModel.page?.backForwardList.forwardList.isEmpty == false
    }

    private var shouldShowFullControls: Bool {
        viewModel.overlayState.shouldShowToolbars && !viewModel.readingModeEnabled && !readingModeMenuExpanded
    }

    private var shouldShowCollapsedAddress: Bool {
        !viewModel.overlayState.shouldShowToolbars && !viewModel.readingModeEnabled && !readingModeMenuExpanded
    }

    private var shouldShowReadingModeButtonOnly: Bool {
        viewModel.readingModeEnabled && !readingModeMenuExpanded
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
        .frame(width: floatingButtonFrameSize, height: floatingButtonFrameSize)
        .contentShape(.circle)
        .buttonStyle(.plain)
        .glassEffect(in: Circle())
        .accessibilityLabel(accessibilityLabel)
    }

    private func beginAddressEditing() {
        withAnimation(.easeInOut(duration: 0.25)) {
            viewModel.overlayState = .showingToolbars
        }
        isEditingAddress = true
        isAddressFocused = true
    }

    private func submitAddress() {
        viewModel.navigate(to: viewModel.addressBarText)
        isAddressFocused = false
    }
}

private struct AddressBarCapsuleView: View {
    @Binding var addressText: String
    @Binding var addressSelection: TextSelection?
    @Binding var shouldFocus: Bool
    let isEditingAddress: Bool
    let displayText: String
    let isLoading: Bool
    let namespace: Namespace.ID
    let iconSize: CGFloat
    let accessorySize: CGFloat
    let onBeginEditing: () -> Void
    let onSubmit: () -> Void
    let onReload: () -> Void
    let onStopLoading: () -> Void

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

                TextField("Enter URL", text: $addressText, selection: $addressSelection)
                    .keyboardType(.URL)
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

            Button(action: isLoading ? onStopLoading : onReload) {
                Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                    .font(.system(size: iconSize, weight: .semibold))
            }
            .frame(width: accessorySize, height: accessorySize)
            .contentShape(.circle)
            .buttonStyle(.plain)
            .accessibilityLabel(isLoading ? "Stop Loading" : "Reload")
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
