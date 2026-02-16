// MangaReaderView.swift
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

/// The main manga reader view with paging, toolbars, and dictionary integration.
public struct MangaReaderView: View {
    @ScaledMetric(relativeTo: .body) private var floatingButtonIconSize: CGFloat = 15
    @ScaledMetric(relativeTo: .body) private var floatingButtonFrameSize: CGFloat = 40

    @State private var viewModel: MangaReaderViewModel
    @State private var searchSheetViewModel: DictionarySearchViewModel?
    @State private var isShowingPageJumpDialog: Bool = false
    @State private var pageJumpInput: String = ""
    @State private var tourManager = TourManager()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    public init(manga: MangaArchive) {
        _viewModel = State(wrappedValue: MangaReaderViewModel(manga: manga))
    }

    public var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            ZStack(alignment: .topLeading) {
                Color(.systemBackground)
                    .ignoresSafeArea()
                pageContainer
                    .ignoresSafeArea()
                    .safeAreaInset(edge: .top) {
                        if viewModel.overlayState.shouldShowToolbars {
                            floatingBackButton
                        } else {
                            floatingBackButton.hidden()
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        if viewModel.overlayState.shouldShowToolbars {
                            bottomToolbarOverlay
                        } else {
                            bottomToolbarOverlay.hidden()
                        }
                    }
            }
            .onAppear {
                viewModel.updateOrientation(isLandscape)
            }
            .onChange(of: isLandscape) { _, newValue in
                viewModel.updateOrientation(newValue)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $viewModel.showingDictionarySheet) {
            NavigationStack {
                if let sheetViewModel = searchSheetViewModel {
                    DictionarySearchView()
                        .environment(sheetViewModel)
                        .navigationTitle("Dictionary")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    viewModel.showingDictionarySheet = false
                                }
                            }
                        }
                }
            }
            .onAppear {
                if let text = viewModel.pendingSearchText {
                    let vm = DictionarySearchViewModel(resultState: .searching)
                    vm.performSearch(text, contextValues: viewModel.pendingContextValues)
                    searchSheetViewModel = vm
                    viewModel.clearPendingSearch()
                }
            }
            .onDisappear {
                searchSheetViewModel = nil
            }
            .presentationDetents([.medium, .large])
        }
        .task {
            await viewModel.loadArchive()
        }
        .onDisappear {
            viewModel.saveOnDisappear()
        }
        .statusBar(hidden: !viewModel.overlayState.shouldShowToolbars)
        .overlay(alignment: .top) {
            if viewModel.overlayState.shouldShowToolbars {
                Rectangle()
                    .fill(.clear)
                    .glassEffect()
                    .ignoresSafeArea(edges: .top)
                    .frame(height: 0)
            } else {
                Rectangle()
                    .fill(.clear)
                    .glassEffect()
                    .ignoresSafeArea(edges: .top)
                    .frame(height: 0)
                    .hidden()
            }
        }
        .animation(.easeInOut, value: viewModel.overlayState.shouldShowToolbars)
        .tourOverlay(manager: tourManager)
        .onAppear {
            if tourManager.startIfNeeded(MangaReaderTour.self) {
                viewModel.overlayState = .showingToolbars
            }
        }
    }

    // MARK: - Page Container

    @ViewBuilder
    private var pageContainer: some View {
        switch viewModel.readingDirection {
        case .leftToRight, .rightToLeft:
            if viewModel.isSpreadModeActive {
                spreadPagedView
            } else {
                horizontalPagedView
            }
        case .vertical:
            verticalScrollView
        }
    }

    private var horizontalPagedView: some View {
        TabView(selection: $viewModel.currentPageIndex) {
            ForEach(0 ..< max(1, viewModel.pageCount), id: \.self) { pageIndex in
                MangaPageView(pageIndex: pageIndex, viewModel: viewModel)
                    .tag(pageIndex)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .environment(\.layoutDirection, viewModel.readingDirection == .rightToLeft ? .rightToLeft : .leftToRight)
    }

    private var spreadPagedView: some View {
        TabView(selection: $viewModel.currentSpreadIndex) {
            ForEach(Array(viewModel.spreadLayout.items.enumerated()), id: \.offset) { index, item in
                MangaSpreadView(spreadItem: item, viewModel: viewModel)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .environment(\.layoutDirection, viewModel.readingDirection == .rightToLeft ? .rightToLeft : .leftToRight)
    }

    private var verticalScrollView: some View {
        GeometryReader { geometry in
            // Use full height including safe areas so toolbar changes don't affect page size
            let pageHeight = geometry.size.height

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(0 ..< max(1, viewModel.pageCount), id: \.self) { pageIndex in
                            MangaPageView(pageIndex: pageIndex, viewModel: viewModel)
                                .frame(height: pageHeight)
                                .id(pageIndex)
                        }
                    }
                }
                .scrollTargetBehavior(.paging)
                .onAppear {
                    // Scroll to current page when entering vertical mode
                    proxy.scrollTo(viewModel.currentPageIndex, anchor: .top)
                }
                .onChange(of: viewModel.currentPageIndex) { _, newValue in
                    withAnimation {
                        proxy.scrollTo(newValue, anchor: .top)
                    }
                }
            }
        }
    }

    private var floatingBackButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: floatingButtonIconSize, weight: .semibold))
                .frame(width: floatingButtonFrameSize, height: floatingButtonFrameSize)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Back")
        .tourAnchor(MangaReaderTourAnchor.backButton)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.top, 20)
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbarOverlay: some View {
        HStack(spacing: 20) {
            // Bounding box toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.showBoundingBoxes.toggle()
                }
            } label: {
                Image(systemName: viewModel.showBoundingBoxes ? "text.viewfinder" : "viewfinder")
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel(viewModel.showBoundingBoxes ? "Hide text regions" : "Show text regions")
            .tourAnchor(MangaReaderTourAnchor.textRegions)

            // Spread mode toggle (only in landscape + horizontal mode)
            if viewModel.isLandscape, viewModel.readingDirection != .vertical {
                Divider()
                    .frame(height: 20)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.forceSinglePage.toggle()
                    }
                } label: {
                    Image(systemName: viewModel.forceSinglePage ? "rectangle" : "rectangle.split.2x1")
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .accessibilityLabel(viewModel.forceSinglePage ? "Switch to spreads" : "Switch to single page")
                .tourAnchor(MangaReaderTourAnchor.spreadToggle)
            }

            Divider()
                .frame(height: 20)

            // Reading direction picker
            Picker("Direction", selection: $viewModel.readingDirection) {
                Image(systemName: "arrow.left")
                    .accessibilityLabel("Right to left")
                    .tag(MangaReadingDirection.rightToLeft)
                Image(systemName: "arrow.right")
                    .accessibilityLabel("Left to right")
                    .tag(MangaReadingDirection.leftToRight)
                Image(systemName: "arrow.down")
                    .accessibilityLabel("Vertical")
                    .tag(MangaReadingDirection.vertical)
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
            .accessibilityLabel("Reading direction")
            .tourAnchor(MangaReaderTourAnchor.readingDirection)

            Divider()
                .frame(height: 20)

            // Page indicator
            pageIndicator
                .tourAnchor(MangaReaderTourAnchor.pageIndicator)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .glassEffect(in: .capsule)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 20)
    }

    private var pageIndicator: some View {
        let pages = viewModel.spreadLayout.pages(atSpreadIndex: viewModel.currentSpreadIndex)
        let displayText = if viewModel.isSpreadModeActive, pages.count == 2 {
            // Show range for spreads (e.g., "3-4 / 10")
            "\(pages.min()! + 1)-\(pages.max()! + 1) / \(viewModel.pageCount)"
        } else {
            // Show single page
            "\(viewModel.currentPageIndex + 1) / \(viewModel.pageCount)"
        }

        return Button {
            preparePageJump()
        } label: {
            Text(displayText)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(toolbarSecondaryColor)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
        }
        .accessibilityLabel("Page \(displayText)")
        .accessibilityHint("Jump to a page")
        .alert("Go to Page", isPresented: $isShowingPageJumpDialog) {
            TextField("Page number", text: $pageJumpInput)
                .keyboardType(.numberPad)
                .onChange(of: pageJumpInput) { _, newValue in
                    pageJumpInput = newValue.filter(\.isNumber)
                }
            Button("Go") {
                performPageJump()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a page number between 1 and \(viewModel.pageCount).")
        }
    }

    private func preparePageJump() {
        guard viewModel.pageCount > 0 else { return }
        pageJumpInput = String(viewModel.currentPageIndex + 1)
        isShowingPageJumpDialog = true
    }

    private func performPageJump() {
        let trimmed = pageJumpInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let pageNumber = Int(trimmed), viewModel.pageCount > 0 else { return }
        let clampedPage = min(max(pageNumber, 1), viewModel.pageCount)
        viewModel.goToPage(clampedPage - 1)
    }

    // MARK: - Interface Colors

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
