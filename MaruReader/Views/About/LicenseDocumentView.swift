// LicenseDocumentView.swift
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

import SwiftUI

struct LicenseDocumentView: View {
    let title: String
    let document: ThirdPartyLicenseDocument

    @State private var content: String?
    @State private var loadError: String?

    var body: some View {
        Group {
            if let content {
                ScrollView {
                    Text(verbatim: content)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            } else if let loadError {
                ContentUnavailableView(
                    "Could Not Load License",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(loadError)
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDocument()
        }
    }

    @MainActor
    private func loadDocument() async {
        do {
            content = try ThirdPartyLicenseCatalogLoader.documentText(for: document.path)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        LicenseDocumentView(
            title: "Preview License",
            document: ThirdPartyLicenseDocument(
                title: "GNU GPLv3",
                path: ThirdPartyLicenseCatalogLoader.appLicensePath,
                referenceURL: URL(string: "https://www.gnu.org/licenses/gpl-3.0.txt")
            )
        )
    }
}
