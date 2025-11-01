//
//  OCRScanView.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/31/25.
//

import os.log
import PhotosUI
import SwiftUI
import Vision

struct OCRScanView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var observations = [TextObservationData]()
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var selectedObservation: TextObservationData?

    private var request: RecognizeTextRequest

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "OCRScanView")

    init() {
        self.request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = [.init(identifier: "ja-JP")]
    }

    var body: some View {
        NavigationStack {
            VStack {
                if let image = selectedImage {
                    imageView(image)
                } else {
                    placeholderView
                }
            }
            .navigationTitle("Scan")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("Select Photo", systemImage: "photo.on.rectangle")
                    }
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    await loadImage(from: newItem)
                }
            }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
            .sheet(item: $selectedObservation) { _ in
                if let observation = selectedObservation {
                    textDetailSheet(for: observation)
                }
            }
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
            Text("Select a photo to scan")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func imageView(_ image: UIImage) -> some View {
        GeometryReader { geometry in
            let imageRect = calculateImageRect(image: image, in: geometry.size)

            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)

                if !isProcessing {
                    ForEach(Array(observations.enumerated()), id: \.offset) { index, observation in
                        let boxRect = calculateBoxRect(observation: observation.observation, in: imageRect)

                        Rectangle()
                            .stroke(Color.blue, lineWidth: 2)
                            .frame(width: boxRect.width, height: boxRect.height)
                            .offset(x: boxRect.minX, y: boxRect.minY)
                            .onTapGesture {
                                logger.debug("Tapped observation \(index)")
                                selectedObservation = observation
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

    private func textDetailSheet(for observation: TextObservationData) -> some View {
        logger.debug("Showing text detail sheet")
        logger.debug("Detected text: \(observation.observation.topCandidates(1).first?.string ?? "None")")

        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let text = observation.observation.topCandidates(1).first?.string {
                        Text(text)
                            .font(.body)
                            .textSelection(.enabled)
                            .padding()
                    } else {
                        Text("No text detected")
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Detected Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selectedObservation = nil
                    }
                }
            }
        }
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }

        isProcessing = true
        errorMessage = nil

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "Failed to load image data"
                isProcessing = false
                return
            }

            guard let image = UIImage(data: data) else {
                errorMessage = "Failed to create image from data"
                isProcessing = false
                return
            }

            selectedImage = image

            // Perform OCR
            try await performOCR(imageData: data)

            isProcessing = false
        } catch {
            errorMessage = "OCR failed: \(error.localizedDescription)"
            isProcessing = false
        }
    }

    private func performOCR(imageData: Data) async throws {
        /// Clear the `observations` array for photo recapture.
        observations.removeAll()

        /// Perform the request on the image data and return the results.
        let results = try await request.perform(on: imageData)

        logger.debug("OCR found \(String(describing: results.count)) text observations.")

        /// Add each observation to the `observations` array.
        for observation in results {
            observations.append(TextObservationData(observation: observation))
        }
    }
}

struct TextObservationData: Identifiable {
    let id = UUID()
    let observation: RecognizedTextObservation
}
