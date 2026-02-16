// AboutView.swift
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

struct AboutView: View {
    private let repositoryURL = URL(string: "https://github.com/classicsc/MaruReader")!

    var body: some View {
        Form {
            Section("App") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Build", value: appBuild)
            }

            Section("Project") {
                Link("Source Code Repository", destination: repositoryURL)

                NavigationLink("MaruReader License (GPLv3)") {
                    LicenseDocumentView(
                        title: "MaruReader License (GPLv3)",
                        document: ThirdPartyLicenseDocument(
                            title: "GNU General Public License Version 3",
                            path: ThirdPartyLicenseCatalogLoader.appLicensePath,
                            referenceURL: URL(string: "https://www.gnu.org/licenses/gpl-3.0.txt")
                        )
                    )
                }

                NavigationLink("Third-Party Licenses") {
                    ThirdPartyLicensesView()
                }
            }
        }
        .navigationTitle("About")
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
