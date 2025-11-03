//
//  ContextDisplayView.swift
//  MaruReader
//
//  Displays the context text for a dictionary lookup with character-level tap handling.
//
import SwiftUI

struct ContextDisplayView: View {
    let context: String
    let matchRange: Range<String.Index>?
    let onCharacterTap: (Int) -> Void

    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with collapse/expand button
            Button(action: {
                withAnimation(.snappy) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text("Context")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Context text display
            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(context.enumerated()), id: \.offset) { index, character in
                            let stringIndex = context.index(context.startIndex, offsetBy: index)
                            let isInMatch = matchRange?.contains(stringIndex) ?? false

                            Text(String(character))
                                .font(.body)
                                .padding(.horizontal, 2)
                                .padding(.vertical, 4)
                                .background(
                                    isInMatch
                                        ? Color.accentColor.opacity(0.2)
                                        : Color.clear
                                )
                                .cornerRadius(4)
                                .onTapGesture {
                                    onCharacterTap(index)
                                }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
    }
}

#Preview {
    let context = "これは日本語のテキストです"
    let matchStart = context.index(context.startIndex, offsetBy: 2)
    let matchEnd = context.index(context.startIndex, offsetBy: 5)

    ContextDisplayView(
        context: context,
        matchRange: matchStart ..< matchEnd,
        onCharacterTap: { offset in
            print("Tapped character at offset: \(offset)")
        }
    )
    .padding()
}
