// UnifiedTokenizerDictionaryManagementMetadataView.swift
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

struct UnifiedTokenizerDictionaryManagementMetadataView: View {
    let tokenizerDictionary: TokenizerDictionary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let version = tokenizerDictionary.version, !version.isEmpty {
                UnifiedDictionaryManagementMetadataField("Version", value: version)
            }

            if let attribution = tokenizerDictionary.attribution, !attribution.isEmpty {
                UnifiedDictionaryManagementMetadataField("Attribution", value: attribution)
            }

            if let indexURL = tokenizerDictionary.indexURL,
               let parsedIndexURL = URL(string: indexURL)
            {
                UnifiedDictionaryManagementMetadataField("Index") {
                    Link(destination: parsedIndexURL) {
                        Text(verbatim: indexURL)
                    }
                }
            }

            if let downloadURL = tokenizerDictionary.downloadURL,
               let parsedDownloadURL = URL(string: downloadURL)
            {
                UnifiedDictionaryManagementMetadataField("Download") {
                    Link(destination: parsedDownloadURL) {
                        Text(verbatim: downloadURL)
                    }
                }
            }
        }
        .font(.caption)
        .padding(.top, 4)
    }
}
