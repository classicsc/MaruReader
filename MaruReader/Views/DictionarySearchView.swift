//  DictionarySearchView.swift
//  MaruReader
//
//  Stub view for dictionary search functionality.
//
import SwiftUI

struct DictionarySearchView: View {
    @State private var query: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Search dictionary", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .padding(.top)
                Group {
                    if query.isEmpty {
                        ContentUnavailableView("Start typing to search", systemImage: "magnifyingglass", description: Text("Dictionary results will appear here."))
                    } else {
                        List {
                            // Placeholder sample results
                            ForEach(sampleResults(for: query), id: \.self) { term in
                                VStack(alignment: .leading) {
                                    Text(term).font(.headline)
                                    Text("Stub definition for \(term)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .animation(.default, value: query)
                Spacer()
            }
            .padding(.horizontal)
            .navigationTitle("Dictionary")
        }
    }

    private func sampleResults(for text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        return (1 ... 5).map { "\(text) \($0)" }
    }
}

#Preview {
    DictionarySearchView()
}
