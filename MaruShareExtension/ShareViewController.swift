import MaruDictionaryUICommon
import MaruVision
import MaruVisionUICommon
import Social
import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first
        else {
            cancelRequest()
            return
        }

        // Check if it's an image (direct image data)
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            handleImageShare(itemProvider: itemProvider)
        }
        // Check if it's a URL (web images from Safari)
        else if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            handleURLShare(itemProvider: itemProvider)
        }
        // Check if it's text
        else if itemProvider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
            handleTextShare(itemProvider: itemProvider)
        } else {
            cancelRequest()
        }
    }

    private func handleTextShare(itemProvider: NSItemProvider) {
        itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { [weak self] item, _ in
            guard let text = item as? String else {
                self?.cancelRequest()
                return
            }

            DispatchQueue.main.async {
                self?.showSearchView(mode: .text(query: text))
            }
        }
    }

    private func handleImageShare(itemProvider: NSItemProvider) {
        itemProvider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] item, error in
            guard error == nil else {
                self?.cancelRequest()
                return
            }

            var imageData: Data?

            // Handle different image item types
            if let data = item as? Data {
                imageData = data
            } else if let url = item as? URL {
                imageData = try? Data(contentsOf: url)
            } else if let image = item as? UIImage {
                imageData = image.jpegData(compressionQuality: 1.0)
            }

            guard let data = imageData, let image = UIImage(data: data) else {
                self?.cancelRequest()
                return
            }

            DispatchQueue.main.async {
                self?.showSearchView(mode: .image(image: image, imageData: data))
            }
        }
    }

    private func handleURLShare(itemProvider: NSItemProvider) {
        itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, error in
            guard error == nil, let url = item as? URL else {
                self?.cancelRequest()
                return
            }

            // Download the content from the URL
            Task { @MainActor [weak self] in
                guard let self else { return }

                do {
                    let (data, _) = try await URLSession.shared.data(from: url)

                    // Try to create an image from the downloaded data
                    if let image = UIImage(data: data) {
                        self.showSearchView(mode: .image(image: image, imageData: data))
                    } else {
                        // Not an image, cancel
                        self.cancelRequest()
                    }
                } catch {
                    // Failed to download or process
                    self.cancelRequest()
                }
            }
        }
    }

    private func showSearchView(mode: SearchView.Mode) {
        let searchView = SearchView(mode: mode) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }

        let hostingController = UIHostingController(rootView: searchView)

        // Present or embed the SwiftUI view
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingController.didMove(toParent: self)
    }

    private func cancelRequest() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}

struct SearchView: View {
    enum Mode {
        case text(query: String)
        case image(image: UIImage, imageData: Data)
    }

    @State private var viewModel = DictionarySearchViewModel(resultState: .searching)
    @State private var ocr = OCR()
    @State private var isProcessing = false
    @State private var errorMessage: String?

    private let mode: Mode
    private let onDismiss: (() -> Void)?

    init(mode: Mode, onDismiss: (() -> Void)? = nil) {
        self.mode = mode
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case let .text(query):
                    DictionarySearchView()
                        .environment(viewModel)
                        .onAppear {
                            viewModel.performSearch(query)
                        }

                case let .image(image, imageData):
                    OCRImageResultsView(
                        image: image,
                        observations: ocr.observations,
                        isProcessing: isProcessing
                    )
                    .task {
                        await performOCR(imageData: imageData)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onDismiss?()
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

    private func performOCR(imageData: Data) async {
        isProcessing = true
        errorMessage = nil

        do {
            try await ocr.performOCR(imageData: imageData)
            isProcessing = false
        } catch {
            errorMessage = "OCR failed: \(error.localizedDescription)"
            isProcessing = false
        }
    }
}
