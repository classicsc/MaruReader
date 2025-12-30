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
    /// The array of the request's results.
    private var observations = [RecognizedTextObservation]()

    /// Clustered observations for UI interaction.
    @MainActor public var clusters = [TextCluster]()

    /// The Vision request.
    var request: RecognizeTextRequest

    /// Configuration for text clustering.
    public var clusteringConfiguration: ClusteringConfiguration = .default

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "OCR")

    public init(clusteringConfiguration: ClusteringConfiguration = .default) {
        self.clusteringConfiguration = clusteringConfiguration

        /// Initialize the request with default parameters.
        request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = [.init(identifier: "ja-JP")]
    }

    public func performOCR(imageData: Data) async throws {
        /// Clear the arrays for photo recapture.
        observations.removeAll()
        await MainActor.run {
            clusters.removeAll()
        }

        /// Perform the request on the image data and return the results.
        let results = try await request.perform(on: imageData)

        logger.debug("OCR found \(results.count) text observations.")

        // Cluster the results
        let clusterer = TextClusterer(configuration: clusteringConfiguration)
        let clusteredResults = clusterer.cluster(results)

        logger.debug("Clustered into \(clusteredResults.count) clusters.")

        /// Update the published arrays on main actor.
        observations = results
        await MainActor.run {
            clusters = clusteredResults
        }
    }

    /// Re-cluster existing observations with a new configuration.
    /// Useful for adjusting clustering parameters without re-running OCR.
    public func recluster(with configuration: ClusteringConfiguration) async {
        let currentObservations = observations
        guard !currentObservations.isEmpty else { return }

        let clusterer = TextClusterer(configuration: configuration)
        let clusteredResults = clusterer.cluster(currentObservations)
        clusteringConfiguration = configuration

        await MainActor.run {
            clusters = clusteredResults
        }

        logger.debug("Re-clustered \(currentObservations.count) observations into \(clusteredResults.count) clusters.")
    }
}
