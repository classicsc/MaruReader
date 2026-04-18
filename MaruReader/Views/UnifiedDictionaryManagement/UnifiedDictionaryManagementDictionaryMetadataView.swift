// UnifiedDictionaryManagementDictionaryMetadataView.swift
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

struct UnifiedDictionaryManagementDictionaryMetadataView: View {
    let dictionary: Dictionary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let author = dictionary.author, !author.isEmpty {
                UnifiedDictionaryManagementMetadataField("Author", value: author)
            }

            if let attribution = dictionary.attribution, !attribution.isEmpty {
                UnifiedDictionaryManagementMetadataField("Attribution", value: attribution)
            }

            if let description = dictionary.displayDescription, !description.isEmpty {
                UnifiedDictionaryManagementMetadataField("Description", value: description)
            }

            if let revision = dictionary.revision, !revision.isEmpty {
                UnifiedDictionaryManagementMetadataField("Revision", value: revision)
            }

            if let url = dictionary.url,
               let projectURL = URL(string: url)
            {
                UnifiedDictionaryManagementMetadataField("Project") {
                    Link(destination: projectURL) {
                        Text(verbatim: url)
                    }
                }
            }
        }
        .font(.caption)
        .padding(.top, 4)
    }
}
