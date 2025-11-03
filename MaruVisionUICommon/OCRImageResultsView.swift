//
//  OCRImageResultsView.swift
//  MaruReader
//
//  Created by Claude Code on 11/2/25.
//

import MaruDictionaryUICommon
import MaruVision
import os.log
import SwiftUI
import Vision

/// A reusable view that displays an image with OCR results as tappable bounding boxes.
/// When a text region is tapped, presents a dictionary search sheet.
public struct OCRImageResultsView: View {
    let image: UIImage
    let observations: [TextObservationData]
    let isProcessing: Bool

    @State private var selectedObservation: TextObservationData?
    @State private var searchSheetViewModel = DictionarySearchViewModel(resultState: .searching)

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "OCRImageResultsView")

    /// Initialize the OCR results view
    /// - Parameters:
    ///   - image: The image to display
    ///   - observations: Array of text observations detected by OCR
    ///   - isProcessing: Whether OCR is currently processing
    public init(image: UIImage, observations: [TextObservationData], isProcessing: Bool = false) {
        self.image = image
        self.observations = observations
        self.isProcessing = isProcessing
    }

    public var body: some View {
        GeometryReader { geometry in
            let imageRect = calculateImageRect(image: image, in: geometry.size)

            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)

                if !isProcessing {
                    if observations.isEmpty {
                        // Empty state - no text detected
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 50))
                                .foregroundStyle(.secondary)
                            Text("No text detected")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                    } else {
                        // Display tappable bounding boxes
                        ForEach(Array(observations.enumerated()), id: \.offset) { index, observation in
                            let boxRect = calculateBoxRect(observation: observation.observation, in: imageRect)

                            Rectangle()
                                .strokeBorder(Color.blue, lineWidth: 2)
                                .background(Color.blue.opacity(0.0))
                                .frame(width: boxRect.width, height: boxRect.height)
                                .position(x: boxRect.midX, y: boxRect.midY)
                                .onTapGesture {
                                    logger.debug("Tapped observation \(index)")
                                    selectedObservation = observation
                                }
                        }
                    }
                }

                if isProcessing {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
        }
        .sheet(item: $selectedObservation) { _ in
            NavigationStack {
                DictionarySearchView()
                    .environment(searchSheetViewModel)
                    .navigationTitle("Dictionary")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                selectedObservation = nil
                            }
                        }
                    }
            }
            .onAppear {
                // Initialize the view model with the transcript
                searchSheetViewModel.performSearch(selectedObservation?.observation.transcript ?? "")
            }
            .presentationDetents([.medium, .large])
        }
    }

    /// Calculate the actual rect where the image is displayed within the container
    private func calculateImageRect(image: UIImage, in containerSize: CGSize) -> CGRect {
        let imageAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height

        let imageRect: CGRect
        if imageAspect > containerAspect {
            // Image is wider - fit to width
            let width = containerSize.width
            let height = width / imageAspect
            let yOffset = (containerSize.height - height) / 2
            imageRect = CGRect(x: 0, y: yOffset, width: width, height: height)
        } else {
            // Image is taller - fit to height
            let height = containerSize.height
            let width = height * imageAspect
            let xOffset = (containerSize.width - width) / 2
            imageRect = CGRect(x: xOffset, y: 0, width: width, height: height)
        }

        return imageRect
    }

    /// Calculate the actual rect for an observation's bounding box within the image rect
    private func calculateBoxRect(observation: RecognizedTextObservation, in imageRect: CGRect) -> CGRect {
        // Convert normalized coordinates to image coordinates (with upper-left origin)
        let boxInImage = observation.boundingBox.toImageCoordinates(imageRect.size, origin: .upperLeft)

        // Offset by the image rect's position within the container
        return boxInImage.offsetBy(dx: imageRect.minX, dy: imageRect.minY)
    }
}
