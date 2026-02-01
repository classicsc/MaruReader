// WelcomeView.swift
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

/// Welcome screen shown on first launch while the dictionary is being set up.
struct WelcomeView: View {
    let isSeedingComplete: Bool
    let onContinue: () -> Void

    @State private var isPreparingDictionary = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App icon and title
            VStack(spacing: 16) {
                Image("AppIconImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 22))

                Text("Welcome to MaruReader")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }

            // Feature list
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "books.vertical",
                    title: "Read",
                    description: "Read books in ePub format and manga in CBZ format"
                )
                FeatureRow(
                    icon: "globe",
                    title: "Browse",
                    description: "Web browser with OCR reading mode"
                )
                FeatureRow(
                    icon: "doc.text.viewfinder",
                    title: "Scan",
                    description: "OCR text from images"
                )
                FeatureRow(
                    icon: "character.book.closed.ja",
                    title: "Dictionary",
                    description: "Japanese-English dictionary included; import Yomitan custom dictionaries for more features"
                )
                FeatureRow(
                    icon: "rectangle.stack",
                    title: "Anki Integration",
                    description: "Create flashcards with the AnkiMobile app or Anki-Connect addon"
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            Button(action: handleContinue) {
                Group {
                    if isPreparingDictionary {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Preparing dictionary...")
                        }
                    } else {
                        Text("Continue")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .contentTransition(.opacity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPreparingDictionary)
            .padding(.horizontal, 32)
        }
    }

    private func handleContinue() {
        if isSeedingComplete {
            onContinue()
            return
        }

        withAnimation(.easeInOut) {
            isPreparingDictionary = true
        }
        onContinue()
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
