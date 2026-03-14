// WebViewerTabSwitcherSheet.swift
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

struct WebViewerTabSwitcherSheet: View {
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
                    WebViewerTabSwitcherRow(
                        tab: tab,
                        isSelected: tab.id == selectedTabID,
                        onSelect: { onSelect(tab.id) },
                        onClose: { onClose(tab.id) }
                    )
                }
                .onMove(perform: onMove)
            }
            .navigationTitle(WebLocalization.string("Tabs", comment: "The title of the sheet that lists browser tabs."))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onAddTab) {
                        Text(WebLocalization.string("New Tab", comment: "A button that creates a new tab."))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
    }
}
