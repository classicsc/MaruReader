//
//  TextScanning.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/2/25.
//

import CoreGraphics
import Foundation

protocol TextScanning {
    /// Handle tap events and extract text
    func handleTap(at point: CGPoint) async

    /// Apply highlighting to scanned text
    func applyHighlight(_ info: HighlightInfo)

    /// Remove all highlights
    func clearHighlights()
}

struct HighlightInfo: Codable {
    let cssPath: String? // For CSS Highlight API
    let range: Range<Int> // Range to highlight
    let color: String // Highlight color (CSS format)
}
