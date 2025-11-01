//
//  OCR.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/31/25.
//

import os.log
import SwiftUI
import Vision

public actor OCR {
    /// The array of `RecognizedTextObservation` objects to hold the request's results.
    @MainActor public var observations = [RecognizedTextObservation]()

    /// The Vision request.
    var request: RecognizeTextRequest

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "OCR")

    public init() {
        /// Initialize the request with default parameters.
        request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = [.init(identifier: "ja-JP")]
    }

    public func performOCR(imageData: Data) async throws {
        /// Clear the `observations` array for photo recapture.
        await MainActor.run {
            observations.removeAll()
        }

        /// Perform the request on the image data and return the results.
        let results = try await request.perform(on: imageData)

        logger.debug("OCR found \(String(describing: results.count)) text observations.")

        /// Add each observation to the `observations` array.
        await MainActor.run {
            for observation in results {
                observations.append(observation)
            }
        }
    }
}
