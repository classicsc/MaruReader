// ContextDisplayView.swift
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

//
//  ContextDisplayView.swift
//  MaruReader
//
//  Displays the context text for a dictionary lookup with character-level tap handling,
//  optional furigana, and edit support.
//

import MaruReaderCore
import SwiftUI

struct ContextDisplayView: View {
    let context: String
    let matchRange: Range<String.Index>?
    let furiganaSegments: [FuriganaSegment]
    let fontSize: Double
    let furiganaEnabled: Bool
    let isEditing: Bool
    let onCharacterTap: (Int) -> Void
    var onCommitEdit: (() -> Void)?

    @Binding var editText: String

    @State private var isExpanded: Bool = true
    @State private var contentHeight: CGFloat = 0
    @State private var measuredWidth: CGFloat = 0

    /// Maximum height for context area
    private let maxHeight: CGFloat = 150

    /// Base font size for context text
    private var baseFontSize: CGFloat { 17 * fontSize }

    /// Furigana font size (smaller than base)
    private var furiganaFontSize: CGFloat { 10 * fontSize }

    /// Line height for text (base + furigana space + spacing)
    private var furiganaLineHeight: CGFloat { baseFontSize + furiganaFontSize + 6 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView

            if isExpanded {
                if isEditing {
                    editView
                } else {
                    contextContentView
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

    private var headerView: some View {
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
    }

    private var editView: some View {
        VStack(spacing: 0) {
            TextEditor(text: $editText)
                .font(.system(size: baseFontSize))
                .padding(.horizontal, 8)
                .frame(minHeight: 60, maxHeight: 160)

            HStack {
                Spacer()
                Button(action: { onCommitEdit?() }) {
                    Text("Done Editing")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }

    private var contextContentView: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: true) {
                contextTextContent(width: geometry.size.width - 24) // Account for horizontal padding
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
            .onAppear {
                measuredWidth = geometry.size.width - 24
                calculateContentHeight()
            }
            .onChange(of: geometry.size.width) { _, newWidth in
                measuredWidth = newWidth - 24
                calculateContentHeight()
            }
        }
        .frame(height: min(contentHeight + 8, maxHeight))
        .onChange(of: context) { _, _ in calculateContentHeight() }
        .onChange(of: furiganaEnabled) { _, _ in calculateContentHeight() }
        .onChange(of: fontSize) { _, _ in calculateContentHeight() }
    }

    @ViewBuilder
    private func contextTextContent(width: CGFloat) -> some View {
        if !furiganaSegments.isEmpty {
            segmentedTextView(width: width)
        } else {
            plainTextView(width: width)
        }
    }

    /// Fallback for when no furigana segments are available
    private func plainTextView(width: CGFloat) -> some View {
        FlowLayout(horizontalSpacing: 0, verticalSpacing: 2) {
            ForEach(Array(context.enumerated()), id: \.offset) { index, character in
                VStack(spacing: 0) {
                    // Reserve space for furigana to maintain consistent line height
                    Text(" ")
                        .font(.system(size: furiganaFontSize))
                        .foregroundColor(.clear)
                    characterView(String(character), charIndex: index)
                }
            }
        }
        .frame(width: width, alignment: .leading)
    }

    /// Segment-based layout that maintains consistent spacing whether furigana is shown or hidden
    private func segmentedTextView(width: CGFloat) -> some View {
        FlowLayout(horizontalSpacing: 0, verticalSpacing: 2) {
            ForEach(furiganaSegments.indices, id: \.self) { segmentIndex in
                let segment = furiganaSegments[segmentIndex]
                furiganaSegmentView(segment: segment)
            }
        }
        .frame(width: width, alignment: .leading)
    }

    private func furiganaSegmentView(segment: FuriganaSegment) -> some View {
        VStack(spacing: 0) {
            // Furigana reading (or empty space to maintain consistent height and width)
            if furiganaEnabled, let reading = segment.reading {
                Text(reading)
                    .font(.system(size: furiganaFontSize))
                    .foregroundColor(.secondary)
            } else {
                // Use the reading text (invisible) to reserve the same width, or a space for height
                Text(segment.reading ?? " ")
                    .font(.system(size: furiganaFontSize))
                    .foregroundColor(.clear)
            }

            // Base text with per-character tap handling and highlighting
            HStack(spacing: 0) {
                ForEach(Array(segment.base.enumerated()), id: \.offset) { charOffset, character in
                    let globalIndex = calculateGlobalIndex(segment: segment, charOffset: charOffset)

                    characterView(String(character), charIndex: globalIndex)
                }
            }
        }
    }

    private func characterView(_ character: String, charIndex: Int) -> some View {
        let stringIndex = context.index(context.startIndex, offsetBy: charIndex, limitedBy: context.endIndex) ?? context.endIndex
        let isHighlighted = matchRange?.contains(stringIndex) ?? false

        return Text(character)
            .font(.system(size: baseFontSize))
            .background(
                isHighlighted
                    ? Color.accentColor.opacity(0.2)
                    : Color.clear
            )
            .onTapGesture {
                onCharacterTap(charIndex)
            }
    }

    private func calculateGlobalIndex(segment: FuriganaSegment, charOffset: Int) -> Int {
        let segmentStart = context.distance(from: context.startIndex, to: segment.baseRange.lowerBound)
        return segmentStart + charOffset
    }

    private func calculateContentHeight() {
        // Estimate content height based on character count and available width
        // This is an approximation - actual height may vary slightly
        let estimatedCharWidth: CGFloat = baseFontSize * 1.1
        let availableWidth: CGFloat = measuredWidth > 0 ? measuredWidth : 300 // Fallback width
        let charsPerLine = max(1, Int(availableWidth / estimatedCharWidth))
        let lineCount = max(1, (context.count + charsPerLine - 1) / charsPerLine)
        // Always use furiganaLineHeight since both views reserve space for furigana
        contentHeight = CGFloat(lineCount) * furiganaLineHeight
    }
}

// MARK: - Preview

#Preview {
    let context = "これは日本語のテキストです。長い文章をテストするために、もっとテキストを追加します。"
    let matchStart = context.index(context.startIndex, offsetBy: 2)
    let matchEnd = context.index(context.startIndex, offsetBy: 5)
    let segments = FuriganaGenerator.generateSegments(from: context)

    VStack {
        ContextDisplayView(
            context: context,
            matchRange: matchStart ..< matchEnd,
            furiganaSegments: segments,
            fontSize: 1.0,
            furiganaEnabled: true,
            isEditing: false,
            onCharacterTap: { offset in
                print("Tapped character at offset: \(offset)")
            },
            editText: .constant("")
        )

        ContextDisplayView(
            context: context,
            matchRange: matchStart ..< matchEnd,
            furiganaSegments: segments,
            fontSize: 1.0,
            furiganaEnabled: false,
            isEditing: false,
            onCharacterTap: { offset in
                print("Tapped character at offset: \(offset)")
            },
            editText: .constant("")
        )

        Spacer()
    }
    .padding()
}
