// WelcomeView.swift
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

/// Welcome screen shown on first launch while the dictionary is being set up.
struct WelcomeView: View {
    let phaseDescription: String
    let errorMessage: String?
    let canContinue: Bool
    let isPreparing: Bool
    let onRetry: () -> Void
    let onContinue: () -> Void

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
                    description: "Read books and manga with a fast, customizable dictionary"
                )
                FeatureRow(
                    icon: "globe",
                    title: "Browse",
                    description: "Browse Japanese websites with dictionary and OCR"
                )
                FeatureRow(
                    icon: "doc.text.viewfinder",
                    title: "Scan",
                    description: "Scan text from photos for dictionary lookup"
                )
                FeatureRow(
                    icon: "character.book.closed.ja",
                    title: "Dictionary",
                    description: "Comprehensive dictionary with grammar-aware lookups; Yomitan dictionary support"
                )
                FeatureRow(
                    icon: "rectangle.stack",
                    title: "Anki Integration",
                    description: "Send flashcards to Anki with AnkiMobile app or Anki-Connect addon"
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 16) {
                Group {
                    if let errorMessage {
                        VStack(spacing: 12) {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)

                            Button("Retry", action: onRetry)
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .buttonStyle(.bordered)
                        }
                    } else {
                        HStack(spacing: 12) {
                            if isPreparing {
                                ProgressView()
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            Text(phaseDescription)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button(action: onContinue) {
                    Group {
                        Text("Continue")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canContinue)
            }
            .padding(.horizontal, 32)
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey

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
