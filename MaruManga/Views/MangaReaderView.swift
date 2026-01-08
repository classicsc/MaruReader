// MangaReaderView.swift
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
import SwiftUI

/// The main manga reader view with paging, toolbars, and dictionary integration.
public struct MangaReaderView: View {
    @State private var viewModel: MangaReaderViewModel
    @Environment(\.dismiss) private var dismiss

    public init(manga: MangaArchive) {
        _viewModel = State(wrappedValue: MangaReaderViewModel(manga: manga))
    }

    public var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            ZStack {
                // Main page content
                pageContainer
                    .ignoresSafeArea(.all, edges: .bottom)
            }
            .overlay(alignment: .topLeading) {
                if viewModel.overlayState.shouldShowToolbars {
                    topFloatingBar
                }
            }
            .overlay(alignment: .topTrailing) {
                if viewModel.overlayState.shouldShowToolbarToggleButton {
                    toolbarToggleButton
                        .padding(.trailing, 16)
                        .padding(.top, geometry.safeAreaInsets.top + 8)
                }
            }
            .overlay(alignment: .bottom) {
                if viewModel.overlayState.shouldShowToolbars {
                    bottomToolbar
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
            dictionarySheet
        }
        .task {
            await viewModel.loadArchive()
        }
        .onDisappear {
            viewModel.saveOnDisappear()
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
            let pageHeight = geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom

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
            .ignoresSafeArea()
        }
    }

    // MARK: - Toolbar Toggle Button

    private var toolbarToggleButton: some View {
        Button {
            viewModel.toggleToolbars()
        } label: {
            Image(systemName: "chevron.down.circle.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 2)
        }
    }

    // MARK: - Top Floating Bar

    private var topFloatingBar: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            Text(viewModel.manga.title ?? "Manga")
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        )
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 20) {
            // Bounding box toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.showBoundingBoxes.toggle()
                }
            } label: {
                Image(systemName: viewModel.showBoundingBoxes ? "text.viewfinder" : "viewfinder")
            }

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
                }
                .help(viewModel.forceSinglePage ? "Switch to spreads" : "Switch to single page")
            }

            Divider()
                .frame(height: 20)

            // Reading direction picker
            Picker("Direction", selection: $viewModel.readingDirection) {
                Image(systemName: "arrow.left")
                    .tag(MangaReadingDirection.rightToLeft)
                Image(systemName: "arrow.right")
                    .tag(MangaReadingDirection.leftToRight)
                Image(systemName: "arrow.down")
                    .tag(MangaReadingDirection.vertical)
            }
            .pickerStyle(.segmented)
            .frame(width: 120)

            Divider()
                .frame(height: 20)

            // Page indicator
            pageIndicator
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        )
        .frame(maxWidth: .infinity, alignment: .center)
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

        return Text(displayText)
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }

    // MARK: - Dictionary Sheet

    private var dictionarySheet: some View {
        NavigationStack {
            if let searchViewModel = viewModel.dictionarySearchViewModel {
                DictionarySearchView()
                    .environment(searchViewModel)
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
        .presentationDetents([.medium, .large])
    }
}
