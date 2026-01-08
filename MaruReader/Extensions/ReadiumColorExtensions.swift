// ReadiumColorExtensions.swift
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

import Foundation
import ReadiumNavigator
import SwiftUI

extension ReadiumNavigator.Color {
    /// Returns a CSS hex color string (e.g., "#FFFFFF")
    var cssHex: String {
        let r = (rawValue >> 16) & 0xFF
        let g = (rawValue >> 8) & 0xFF
        let b = rawValue & 0xFF

        func hex(_ value: Int) -> String {
            let str = String(value, radix: 16, uppercase: true)
            return str.count == 1 ? "0" + str : str
        }

        return "#" + hex(r) + hex(g) + hex(b)
    }

    /// Convenience initializer from SwiftUI Color
    init?(swiftUIColor: SwiftUI.Color) {
        self.init(uiColor: UIColor(swiftUIColor))
    }

    /// Convenience property to get SwiftUI Color
    var swiftUIColor: SwiftUI.Color {
        SwiftUI.Color(uiColor)
    }
}
