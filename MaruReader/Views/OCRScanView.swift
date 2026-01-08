// OCRScanView.swift
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
    @State private var showPhotoPicker = false
    @State private var ocr = {
        #if DEBUG
            OCR(clusteringConfiguration: .debug)
        #else
            OCR()
        #endif
    }()

    @State private var clusters = [TextCluster]()

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
                        clusters: clusters,
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
                        Button {
                            showPhotoPicker = true
                        } label: {
                            Label("Choose from Library", systemImage: "photo.on.rectangle")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
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
            clusters = try await ocr.performOCR(imageData: data)
            isProcessing = false
        } catch {
            errorMessage = "OCR failed: \(error.localizedDescription)"
            isProcessing = false
        }
    }
}
