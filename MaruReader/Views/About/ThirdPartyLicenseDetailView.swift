// ThirdPartyLicenseDetailView.swift
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

struct ThirdPartyLicenseDetailView: View {
    let component: ThirdPartyComponent

    var body: some View {
        Form {
            Section("Component") {
                LabeledContent("Name", value: component.name)

                if let version = component.version {
                    LabeledContent("Version", value: version)
                }

                if let revision = component.revision {
                    LabeledContent("Revision", value: revision)
                }

                if let attribution = component.attribution {
                    LabeledContent("Attribution", value: attribution)
                }
            }

            Section("Links") {
                if let homepageURL = component.homepageURL {
                    Link("Homepage", destination: homepageURL)
                }

                if let sourceURL = component.sourceURL {
                    Link("Source", destination: sourceURL)
                }
            }

            Section("Licenses") {
                ForEach(component.licenses, id: \.path) { document in
                    NavigationLink(document.title) {
                        LicenseDocumentView(title: document.title, document: document)
                    }
                }
            }
        }
        .navigationTitle(component.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ThirdPartyLicenseDetailView(
            component: ThirdPartyComponent(
                id: "preview",
                name: "Preview Component",
                category: .spm,
                homepageURL: URL(string: "https://example.com"),
                sourceURL: URL(string: "https://example.com/repo"),
                version: "1.0.0",
                revision: "abcdef123456",
                attribution: "Example Author",
                notes: "Preview note for component metadata.",
                licenses: [
                    ThirdPartyLicenseDocument(
                        title: "MIT License",
                        path: ThirdPartyLicenseCatalogLoader.appLicensePath,
                        referenceURL: URL(string: "https://opensource.org/license/mit")
                    ),
                ]
            )
        )
    }
}
