// StartupPreparingView.swift
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

import SwiftUI

/// Lightweight progress screen shown while `StartupPreparationCoordinator`
/// is warming Core Data stacks and running other startup work.
///
/// The chrome (TabView + Read tab's NavigationStack) intentionally mirrors
/// `ContentView` so that the transition to the real UI when preparation
/// completes is seamless rather than a flash from a hero/welcome screen.
struct StartupPreparingView: View {
    let phaseDescription: String
    let errorMessage: String?
    let onRetry: () -> Void

    var body: some View {
        TabView {
            Tab("Read", systemImage: "books.vertical") {
                NavigationStack {
                    bodyContent
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .principal) {
                                Picker("Library", selection: .constant(LibraryType.books)) {
                                    ForEach(LibraryType.allCases, id: \.self) { type in
                                        Text(type.localizedName).tag(type)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .fixedSize()
                                .disabled(true)
                            }
                        }
                }
            }
            Tab("Scan", systemImage: "doc.text.viewfinder") { bodyContent }
            Tab("Web", systemImage: "globe") { bodyContent }
            Tab("Settings", systemImage: "gear") { bodyContent }
            Tab(role: .search) { bodyContent }
        }
        .tabViewStyle(.sidebarAdaptable)
    }

    @ViewBuilder
    private var bodyContent: some View {
        if let errorMessage {
            ContentUnavailableView {
                Label("Couldn't prepare your library", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Retry", action: onRetry)
                    .buttonStyle(.borderedProminent)
            }
        } else {
            VStack(spacing: 12) {
                ProgressView()
                Text(phaseDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview("Preparing") {
    StartupPreparingView(
        phaseDescription: "Preparing your library...",
        errorMessage: nil,
        onRetry: {}
    )
}

#Preview("Error") {
    StartupPreparingView(
        phaseDescription: "Preparing your library...",
        errorMessage: "Something went wrong while loading your library.",
        onRetry: {}
    )
}
