//
//  OCRScanView.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/31/25.
//

import MaruDictionaryUICommon
import MaruVision
import MaruVisionUICommon
import os.log
import PhotosUI
import SwiftUI
import UIKit
import Vision

struct OCRScanView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showCamera = false
    @State private var ocr = {
        #if DEBUG
            OCR(clusteringConfiguration: .debug)
        #else
            OCR()
        #endif
    }()

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "OCRScanView")

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
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
                    Menu {
                        if isCameraAvailable {
                            Button {
                                showCamera = true
                            } label: {
                                Label("Take Photo", systemImage: "camera")
                            }
                        }
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Label("Choose from Library", systemImage: "photo.on.rectangle")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    await loadImage(from: newItem)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                ImagePickerController { image, data in
                    Task {
                        await processImage(image, data: data)
                    }
                }
                .ignoresSafeArea()
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

            await processImage(image, data: data)
        } catch {
            errorMessage = "OCR failed: \(error.localizedDescription)"
            isProcessing = false
        }
    }

    private func processImage(_ image: UIImage, data: Data) async {
        selectedImage = image
        isProcessing = true
        errorMessage = nil

        do {
            try await ocr.performOCR(imageData: data)
            isProcessing = false
        } catch {
            errorMessage = "OCR failed: \(error.localizedDescription)"
            isProcessing = false
        }
    }
}
