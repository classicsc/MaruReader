// OCRScanView.swift
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
import MaruVisionUICommon
import PhotosUI
import SwiftUI
import UIKit

enum OCRScanSourceAction: Equatable {
    case camera
    case photoLibrary
}

struct OCRScanPresentationState {
    struct Session: Identifiable {
        let id: UUID
        let image: UIImage
        var clusters: [TextCluster]
        var isProcessing: Bool
    }

    struct CapturedImagePayload {
        let image: UIImage
        let data: Data
    }

    var activeSession: Session?
    var isShowingResults = false
    var pendingCameraCapture: CapturedImagePayload?
    var pendingSourceActionAfterResultsDismiss: OCRScanSourceAction?

    mutating func beginSession(image: UIImage) -> UUID {
        let sessionID = UUID()
        activeSession = Session(
            id: sessionID,
            image: image,
            clusters: [],
            isProcessing: true
        )
        isShowingResults = true
        pendingSourceActionAfterResultsDismiss = nil
        return sessionID
    }

    mutating func applyOCRResult(for sessionID: UUID, clusters: [TextCluster]) -> Bool {
        guard activeSession?.id == sessionID else { return false }
        activeSession?.clusters = clusters
        activeSession?.isProcessing = false
        return true
    }

    mutating func applyOCRError(for sessionID: UUID) -> Bool {
        guard activeSession?.id == sessionID else { return false }
        activeSession?.isProcessing = false
        return true
    }

    mutating func queueSourceAfterResultsDismiss(_ sourceAction: OCRScanSourceAction) {
        pendingSourceActionAfterResultsDismiss = sourceAction
        isShowingResults = false
    }

    mutating func handleResultsDismiss() -> OCRScanSourceAction? {
        activeSession = nil
        isShowingResults = false
        let nextSource = pendingSourceActionAfterResultsDismiss
        pendingSourceActionAfterResultsDismiss = nil
        return nextSource
    }

    mutating func storeCameraCapture(image: UIImage, data: Data) {
        pendingCameraCapture = CapturedImagePayload(image: image, data: data)
    }

    mutating func consumeCameraCapture() -> CapturedImagePayload? {
        let payload = pendingCameraCapture
        pendingCameraCapture = nil
        return payload
    }
}

struct OCRScanView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var presentationState = OCRScanPresentationState()
    @State private var ocrTask: Task<Void, Never>?
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

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationStack {
            placeholderView
                .navigationTitle("Scan")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            if isCameraAvailable {
                                Button {
                                    launchSource(.camera)
                                } label: {
                                    Label("Take Photo", systemImage: "camera")
                                }
                            }
                            Button {
                                launchSource(.photoLibrary)
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
                .fullScreenCover(isPresented: $showCamera, onDismiss: handleCameraDismiss) {
                    ImagePickerController { image, data in
                        presentationState.storeCameraCapture(image: image, data: data)
                    }
                    .ignoresSafeArea()
                }
                .fullScreenCover(isPresented: $presentationState.isShowingResults, onDismiss: handleResultsDismiss) {
                    if let session = presentationState.activeSession {
                        NavigationStack {
                            OCRImageResultsView(
                                image: session.image,
                                clusters: session.clusters,
                                isProcessing: session.isProcessing
                            )
                            .navigationTitle("Scan Results")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Done") {
                                        presentationState.isShowingResults = false
                                    }
                                }
                                ToolbarItem(placement: .primaryAction) {
                                    Menu {
                                        if isCameraAvailable {
                                            Button {
                                                queueScanAnother(.camera)
                                            } label: {
                                                Label("Take Photo", systemImage: "camera")
                                            }
                                        }
                                        Button {
                                            queueScanAnother(.photoLibrary)
                                        } label: {
                                            Label("Choose from Library", systemImage: "photo.on.rectangle")
                                        }
                                    } label: {
                                        Label("Scan Another", systemImage: "plus")
                                    }
                                }
                            }
                        }
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

    private func launchSource(_ sourceAction: OCRScanSourceAction) {
        switch sourceAction {
        case .camera:
            guard isCameraAvailable else {
                errorMessage = String(localized: "Camera is unavailable on this device")
                return
            }
            showCamera = true

        case .photoLibrary:
            selectedItem = nil
            showPhotoPicker = true
        }
    }

    private func queueScanAnother(_ sourceAction: OCRScanSourceAction) {
        presentationState.queueSourceAfterResultsDismiss(sourceAction)
    }

    private func handleCameraDismiss() {
        guard let payload = presentationState.consumeCameraCapture() else { return }
        startSession(image: payload.image, data: payload.data)
    }

    private func handleResultsDismiss() {
        ocrTask?.cancel()
        ocrTask = nil
        selectedItem = nil

        let queuedSource = presentationState.handleResultsDismiss()
        if let queuedSource {
            launchSource(queuedSource)
        }
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        defer { selectedItem = nil }

        errorMessage = nil

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = String(localized: "Failed to load image data")
                return
            }

            guard let image = UIImage(data: data) else {
                errorMessage = String(localized: "Failed to create image from data")
                return
            }

            startSession(image: image, data: data)
        } catch {
            errorMessage = AppLocalization.ocrFailed(error.localizedDescription)
        }
    }

    private func startSession(image: UIImage, data: Data) {
        ocrTask?.cancel()

        let sessionID = presentationState.beginSession(image: image)
        errorMessage = nil

        ocrTask = Task { @MainActor in
            do {
                let clusters = try await ocr.performOCR(imageData: data)
                _ = presentationState.applyOCRResult(for: sessionID, clusters: clusters)
            } catch is CancellationError {
                return
            } catch {
                if presentationState.applyOCRError(for: sessionID) {
                    errorMessage = AppLocalization.ocrFailed(error.localizedDescription)
                }
            }

            if presentationState.activeSession?.id == sessionID {
                ocrTask = nil
            }
        }
    }
}
