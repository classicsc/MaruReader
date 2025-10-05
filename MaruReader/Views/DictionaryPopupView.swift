//
//  DictionaryPopupView.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/3/25.
//

import os.log
import ReadiumNavigator
import SwiftUI
import WebKit

struct DictionaryPopupView: View {
    @State var page: WebPage

    var body: some View {
        ZStack {
            WebView(page)
            if page.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: 1)
        )
        .cornerRadius(12)
        .shadow(radius: 10)
    }

    static func computePopupCenter(screenSize: CGSize, popupSize: CGSize = CGSize(width: 300, height: 400), highlightBoundingRects: [[String: Double]]?, readingProgression: ReadingProgression, isVerticalWriting: Bool) -> CGPoint? {
        let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionaryPopupView")
        guard let rects = highlightBoundingRects, !rects.isEmpty else { return nil }

        // Array of all rects
        let unionRect = rects.reduce(into: CGRect.null) { partialResult, dict in
            let left = dict["left"] ?? 0
            let top = dict["top"] ?? 0
            let width = dict["width"] ?? 0
            let height = dict["height"] ?? 0
            let rect = CGRect(x: left, y: top, width: width, height: height)
            partialResult = partialResult.union(rect)
        }

        // First rect for anchoring
        let first = rects[0]
        let anchorLeft = first["left"] ?? 0
        let anchorTop = first["top"] ?? 0
        let anchorWidth = first["width"] ?? 0
        let anchorHeight = first["height"] ?? 0
        let anchorRect = CGRect(x: anchorLeft, y: anchorTop, width: anchorWidth, height: anchorHeight)

        let offset: CGFloat = 2
        let screenRect = CGRect(origin: .zero, size: screenSize)
        let isVertical = isVerticalWriting
        let progression = readingProgression

        // Preferences based on text flow
        let preferences: [Placement] = if !isVertical {
            if progression == .ltr {
                [.belowLeftAligned, .aboveLeftAligned, .rightTopAligned, .leftTopAligned]
            } else {
                [.belowRightAligned, .aboveRightAligned, .leftTopAligned, .rightTopAligned]
            }
        } else {
            if progression == .rtl { // Typical for vertical-rl
                [.leftTopAligned, .rightTopAligned, .belowLeftAligned, .aboveLeftAligned]
            } else {
                [.rightTopAligned, .leftTopAligned, .belowRightAligned, .aboveRightAligned]
            }
        }

        // Try each preference
        for placement in preferences {
            var proposedRect = popupRect(for: placement, anchor: anchorRect, popupSize: popupSize, offset: offset)
            // Adjust to fit in screen
            if proposedRect.minX < 0 { proposedRect.origin.x = 0 }
            if proposedRect.maxX > screenSize.width { proposedRect.origin.x = screenSize.width - popupSize.width }
            if proposedRect.minY < 0 { proposedRect.origin.y = 0 }
            if proposedRect.maxY > screenSize.height { proposedRect.origin.y = screenSize.height - popupSize.height }

            // Check if fits and no overlap
            if screenRect.contains(proposedRect), !proposedRect.intersects(unionRect) {
                logger.debug("Placement: \(placement.description)")
                // Return center point for .position
                return CGPoint(x: proposedRect.midX, y: proposedRect.midY)
            }
        }

        // Fallback: use first preference, adjusted
        let fallbackPlacement = preferences[0]
        var fallbackRect = popupRect(for: fallbackPlacement, anchor: anchorRect, popupSize: popupSize, offset: offset)
        if fallbackRect.minX < 0 { fallbackRect.origin.x = 0 }
        if fallbackRect.maxX > screenSize.width { fallbackRect.origin.x = screenSize.width - popupSize.width }
        if fallbackRect.minY < 0 { fallbackRect.origin.y = 0 }
        if fallbackRect.maxY > screenSize.height { fallbackRect.origin.y = screenSize.height - popupSize.height }
        logger.debug("Fallback Placement: \(fallbackPlacement.description)")
        return CGPoint(x: fallbackRect.midX, y: fallbackRect.midY)
    }

    private static func popupRect(for placement: Placement, anchor: CGRect, popupSize: CGSize, offset: CGFloat) -> CGRect {
        switch placement {
        case .belowLeftAligned:
            CGRect(x: anchor.minX, y: anchor.maxY + offset, width: popupSize.width, height: popupSize.height)
        case .belowRightAligned:
            CGRect(x: anchor.maxX - popupSize.width, y: anchor.maxY + offset, width: popupSize.width, height: popupSize.height)
        case .aboveLeftAligned:
            CGRect(x: anchor.minX, y: anchor.minY - offset - popupSize.height, width: popupSize.width, height: popupSize.height)
        case .aboveRightAligned:
            CGRect(x: anchor.maxX - popupSize.width, y: anchor.minY - offset - popupSize.height, width: popupSize.width, height: popupSize.height)
        case .rightTopAligned:
            CGRect(x: anchor.maxX + offset, y: anchor.minY, width: popupSize.width, height: popupSize.height)
        case .rightBottomAligned:
            CGRect(x: anchor.maxX + offset, y: anchor.maxY - popupSize.height, width: popupSize.width, height: popupSize.height)
        case .leftTopAligned:
            CGRect(x: anchor.minX - offset - popupSize.width, y: anchor.minY, width: popupSize.width, height: popupSize.height)
        case .leftBottomAligned:
            CGRect(x: anchor.minX - offset - popupSize.width, y: anchor.maxY - popupSize.height, width: popupSize.width, height: popupSize.height)
        }
    }
}
