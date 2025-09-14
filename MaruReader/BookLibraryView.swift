//  BookLibraryView.swift
//  MaruReader
//
//  Stub view representing the user's library of books.
//
import SwiftUI

struct BookLibraryView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 48))
                    .symbolRenderingMode(.hierarchical)
                Text("Book Library")
                    .font(.title2)
                Text("Your books will appear here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Library")
        }
    }
}

#Preview {
    BookLibraryView()
}
