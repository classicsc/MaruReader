// OCR.swift
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

import os
import SwiftUI
import Vision

public actor OCR {
    /// The array of the request's results.
    private var observations = [RecognizedTextObservation]()
    /// The Vision request.
    var request: RecognizeTextRequest

    /// Configuration for text clustering.
    public var clusteringConfiguration: ClusteringConfiguration = .default

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "OCR")

    public init(clusteringConfiguration: ClusteringConfiguration = .default) {
        self.clusteringConfiguration = clusteringConfiguration

        // Initialize the request with default parameters.
        request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = [.init(identifier: "ja-JP")]
    }

    /// Enable or disable verbose clustering debug logs.
    /// When enabled, detailed information about merge decisions is logged.
    public func setVerboseLogging(_ enabled: Bool) {
        clusteringConfiguration.verboseLogging = enabled
    }

    public func performOCR(imageData: Data) async throws -> [TextCluster] {
        // Perform the request on the image data and return the results.
        let results = try await request.perform(on: imageData)

        logger.debug("OCR found \(results.count) text observations.")

        // Cluster the results
        let clusterer = TextClusterer(configuration: clusteringConfiguration)
        let clusteredResults = clusterer.cluster(results)

        logger.debug("Clustered into \(clusteredResults.count) clusters.")

        // Update the published arrays on main actor.
        observations = results
        return clusteredResults
    }

    /// Re-cluster existing observations with a new configuration.
    /// Useful for adjusting clustering parameters without re-running OCR.
    public func recluster(with configuration: ClusteringConfiguration) async -> [TextCluster] {
        let currentObservations = observations
        guard !currentObservations.isEmpty else { return [] }

        let clusterer = TextClusterer(configuration: configuration)
        let clusteredResults = clusterer.cluster(currentObservations)
        clusteringConfiguration = configuration
        logger.debug("Re-clustered \(currentObservations.count) observations into \(clusteredResults.count) clusters.")
        return clusteredResults
    }
}
