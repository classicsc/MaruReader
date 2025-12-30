//
//  OCRScanView.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/31/25.
//

import MaruDictionaryUICommon
import MaruVision
import os.log
import PhotosUI
import SwiftUI
import Vision

public struct OCRScanView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var ocr = OCR(clusteringConfiguration: .debug)

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "OCRScanView")

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack {
                if let image = selectedImage {
                    OCRImageResultsView(
                        image: image,
                        clusters: ocr.clusters,
                        isProcessing: isProcessing
                    )
                } else {
                    placeholderView
                }
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
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
            try await ocr.performOCR(imageData: data)

            isProcessing = false
        } catch {
            errorMessage = "OCR failed: \(error.localizedDescription)"
            isProcessing = false
        }
    }
}
