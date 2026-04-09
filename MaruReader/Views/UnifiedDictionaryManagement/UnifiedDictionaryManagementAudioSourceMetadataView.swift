// UnifiedDictionaryManagementAudioSourceMetadataView.swift
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

import MaruDictionaryManagement
import MaruReaderCore
import SwiftUI

struct UnifiedDictionaryManagementAudioSourceMetadataView: View {
    let source: AudioSource

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let attribution = source.attribution, !attribution.isEmpty {
                LabeledContent("Attribution", value: attribution)
            }

            if let pattern = source.urlPattern, !pattern.isEmpty {
                LabeledContent("URL Pattern", value: pattern)
            }

            if let baseRemoteURL = source.baseRemoteURL, !baseRemoteURL.isEmpty {
                LabeledContent("Base URL", value: baseRemoteURL)
            }

            if let audioExtensions = source.audioFileExtensions, !audioExtensions.isEmpty {
                LabeledContent("Audio Extensions", value: audioExtensions)
            }

            if let fileURL = source.file, source.isLocal {
                LabeledContent("Archive", value: fileURL.lastPathComponent)
            }

            if source.version > 0 {
                LabeledContent("Version", value: String(source.version))
            }

            if source.year > 0 {
                LabeledContent("Year", value: String(source.year))
            }
        }
        .font(.caption)
        .padding(.top, 4)
    }
}
