// WebOCRViewModel.swift
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

import MaruVision
import Observation
import os.log
import UIKit

@MainActor
@Observable
final class WebOCRViewModel {
    private let ocr = OCR()
    private let logger = Logger(subsystem: "net.undefinedstar.MaruWeb", category: "WebOCRViewModel")

    var image: UIImage?
    var clusters: [TextCluster] = []
    var isProcessing = false
    var errorMessage: String?

    func reset() {
        image = nil
        clusters = []
        errorMessage = nil
        isProcessing = false
    }

    func performOCR(imageData: Data) async -> [TextCluster] {
        isProcessing = true
        errorMessage = nil

        defer {
            isProcessing = false
        }

        guard let image = UIImage(data: imageData) else {
            errorMessage = "OCR capture failed to decode the image."
            clusters = []
            self.image = nil
            return []
        }

        do {
            let detected = try await ocr.performOCR(imageData: imageData)
            self.image = image
            self.clusters = detected
            return detected
        } catch {
            logger.error("OCR failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            self.image = image
            clusters = []
            return []
        }
    }
}
