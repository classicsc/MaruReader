// MangaSettingsView.swift
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

import MaruManga
import SwiftUI

struct MangaSettingsView: View {
    @AppStorage(MangaMetadataExtractionSettings.smartExtractionEnabledKey)
    private var smartMetadataExtractionEnabled = MangaMetadataExtractionSettings.smartExtractionEnabledDefault
    @AppStorage(MangaTapNavigationSettings.tapToTurnEnabledKey)
    private var tapToTurnEnabled = MangaTapNavigationSettings.tapToTurnEnabledDefault

    private var isMetadataExtractorAvailable: Bool {
        MangaImportManager.isMetadataExtractorAvailable
    }

    var body: some View {
        Form {
            Section(
                header: Text("Reader"),
                footer: Text("Tap the left or right edge of a page to turn pages. Tap the middle to show or hide the toolbars.")
            ) {
                Toggle("Tap Edges to Turn Pages", isOn: $tapToTurnEnabled)
            }
            if isMetadataExtractorAvailable {
                Section(
                    header: Text("Library"),
                    footer: Text("Uses the on-device language model to infer titles and authors from filenames.")
                ) {
                    Toggle("Smart Metadata", isOn: $smartMetadataExtractionEnabled)
                }
            }
        }
        .navigationTitle(Text("Manga"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
