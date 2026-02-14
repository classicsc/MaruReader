// OCRScanPresentationStateTests.swift
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
@testable import MaruReader
import Testing
import UIKit

@MainActor
struct OCRScanPresentationStateTests {
    @Test func beginSession_SetsProcessingAndShowsResultsModal() {
        var state = OCRScanPresentationState()

        let sessionID = state.beginSession(image: makeImage())

        #expect(state.isShowingResults)
        #expect(state.activeSession != nil)
        #expect(state.activeSession?.id == sessionID)
        #expect(state.activeSession?.isProcessing == true)
        #expect(state.activeSession?.clusters.isEmpty == true)
    }

    @Test func applyOCRResult_IgnoresStaleSessionCompletions() {
        var state = OCRScanPresentationState()
        let firstSessionID = state.beginSession(image: makeImage())
        let secondSessionID = state.beginSession(image: makeImage())

        let appliedStale = state.applyOCRResult(for: firstSessionID, clusters: [])
        let appliedCurrent = state.applyOCRResult(for: secondSessionID, clusters: [])

        #expect(!appliedStale)
        #expect(appliedCurrent)
        #expect(state.activeSession?.id == secondSessionID)
        #expect(state.activeSession?.isProcessing == false)
    }

    @Test func queueSourceAfterResultsDismiss_ReturnsQueuedSourceAndResetsState() {
        var state = OCRScanPresentationState()
        _ = state.beginSession(image: makeImage())

        state.queueSourceAfterResultsDismiss(.photoLibrary)
        let queuedSource = state.handleResultsDismiss()

        #expect(queuedSource == .photoLibrary)
        #expect(!state.isShowingResults)
        #expect(state.activeSession == nil)
        #expect(state.pendingSourceActionAfterResultsDismiss == nil)
    }

    @Test func storeAndConsumeCameraCapture_ConsumesOnlyOnce() {
        var state = OCRScanPresentationState()
        let expectedData = Data([0x01, 0x02, 0x03])
        state.storeCameraCapture(image: makeImage(), data: expectedData)

        let firstPayload = state.consumeCameraCapture()
        let secondPayload = state.consumeCameraCapture()

        #expect(firstPayload != nil)
        #expect(firstPayload?.data == expectedData)
        #expect(secondPayload == nil)
    }

    private func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }
}
