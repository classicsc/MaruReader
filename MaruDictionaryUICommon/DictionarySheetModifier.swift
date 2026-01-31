// DictionarySheetModifier.swift
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

/// View modifier that applies adaptive presentation detents for dictionary sheets.
/// On compact horizontal size class (iPhone), uses medium and large detents.
/// On regular horizontal size class (iPad floating sheets), uses only large detent.
private struct DictionarySheetDetentsModifier: ViewModifier {
    let horizontalSizeClass: UserInterfaceSizeClass?

    func body(content: Content) -> some View {
        if horizontalSizeClass == .compact {
            content.presentationDetents([.medium, .large])
        } else {
            content.presentationDetents([.large])
        }
    }
}

public extension View {
    /// Applies adaptive presentation detents for dictionary sheets.
    /// On iPhone (compact), provides medium and large detents for resizing.
    /// On iPad (regular), uses only large detent since the sheet floats centered.
    /// - Parameter horizontalSizeClass: The size class from the presenting view's environment.
    func dictionarySheetDetents(for horizontalSizeClass: UserInterfaceSizeClass?) -> some View {
        modifier(DictionarySheetDetentsModifier(horizontalSizeClass: horizontalSizeClass))
    }
}
