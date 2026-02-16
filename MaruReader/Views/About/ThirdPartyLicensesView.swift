// ThirdPartyLicensesView.swift
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

struct ThirdPartyLicensesView: View {
    @State private var searchText = ""
    @State private var catalog: ThirdPartyLicenseCatalog?
    @State private var loadError: String?

    var body: some View {
        Group {
            if catalog != nil {
                List {
                    ForEach(sortedComponents) { component in
                        NavigationLink {
                            ThirdPartyLicenseDetailView(component: component)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(component.name)
                                if let version = component.version {
                                    Text("Version \(version)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search components")
            } else if let loadError {
                ContentUnavailableView(
                    "Could Not Load Licenses",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadError)
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Third-Party Licenses")
        .task {
            await loadCatalog()
        }
        .refreshable {
            await loadCatalog()
        }
    }

    private var filteredComponents: [ThirdPartyComponent] {
        guard let catalog else { return [] }

        if searchText.isEmpty {
            return catalog.components
        }

        return catalog.components.filter { component in
            component.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var sortedComponents: [ThirdPartyComponent] {
        filteredComponents.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    @MainActor
    private func loadCatalog() async {
        do {
            catalog = try ThirdPartyLicenseCatalogLoader.loadCatalog()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        ThirdPartyLicensesView()
    }
}
