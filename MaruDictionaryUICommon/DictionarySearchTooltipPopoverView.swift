// DictionarySearchTooltipPopoverView.swift
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

struct DictionarySearchTooltipPopoverView: View {
    let text: String
    let presentationTheme: DictionaryPresentationTheme?

    var body: some View {
        ScrollView {
            Text(text)
                .font(.callout)
                .foregroundStyle(themedForegroundColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .background(themedBackgroundColor)
        .frame(minWidth: 200, maxWidth: 320, maxHeight: 240)
    }

    private var themedBackgroundColor: Color {
        presentationTheme?.backgroundColor ?? Color(.systemBackground)
    }

    private var themedForegroundColor: Color {
        presentationTheme?.foregroundColor ?? .primary
    }
}
