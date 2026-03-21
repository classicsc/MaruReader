// DictionarySearchExternalLinkConfirmationView.swift
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

struct DictionarySearchExternalLinkConfirmationView: View {
    let url: URL?
    let onOpen: () -> Void

    @Environment(\.dictionaryPresentationTheme) private var presentationTheme

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Text("Open \(url?.host ?? url?.absoluteString ?? "link") in browser?")
                .font(.subheadline)
                .foregroundStyle(themedSecondaryColor)

            Button("Open", action: onOpen)
        }
        .padding()
        .foregroundStyle(themedForegroundColor)
        .background(themedBackgroundColor)
    }

    private var themedBackgroundColor: Color {
        presentationTheme?.backgroundColor ?? Color(.systemBackground)
    }

    private var themedForegroundColor: Color {
        presentationTheme?.foregroundColor ?? .primary
    }

    private var themedSecondaryColor: Color {
        presentationTheme?.secondaryForegroundColor ?? .secondary
    }
}
