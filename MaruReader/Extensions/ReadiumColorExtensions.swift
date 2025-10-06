//
//  ReadiumColorExtensions.swift
//  MaruReader
//
//  Extensions for Readium's Color type to support CSS hex conversion
//  and SwiftUI interop for the reader preferences system.
//

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
