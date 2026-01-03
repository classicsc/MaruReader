//
//  AnkiMobileSetupView.swift
//  MaruReader
//
//  Step 2: Configure AnkiMobile profile, deck, and note type.
//

import MaruAnki
import SwiftUI
import UIKit

private enum AnkiMobileInfoForAddingError: LocalizedError {
    case missingReturnURL
    case openFailed
    case missingClipboardData

    var errorDescription: String? {
        switch self {
        case .missingReturnURL:
            "Unable to build the return URL for AnkiMobile."
        case .openFailed:
            "Unable to open AnkiMobile."
        case .missingClipboardData:
            "AnkiMobile did not place infoForAdding data on the clipboard."
        }
    }
}

struct AnkiMobileSetupView: View {
    @Bindable var viewModel: AnkiConfigurationViewModel
    @State private var isAwaitingInfoForAdding = false
    @State private var expectedReturnURL: URL?
    private var isBusy: Bool {
        isAwaitingInfoForAdding || viewModel.isLoading
    }

    var body: some View {
        Form {
            Section("Fetch from AnkiMobile") {
                Button {
                    requestInfoForAdding()
                } label: {
                    Label("Fetch profiles, decks, and note types", systemImage: "arrow.down.doc")
                }
                .disabled(isBusy)

                if viewModel.isAnkiMobileInfoLoaded {
                    Text("Loaded \(viewModel.profiles.count) profiles, \(viewModel.decks.count) decks, \(viewModel.models.count) note types.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Opens AnkiMobile and imports the available names when you return.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tap fetch, authorize the request in AnkiMobile, then return to MaruReader.")
                    Text("You will choose a profile, deck, and note type next.")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
        .navigationTitle("AnkiMobile")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Continue") {
                    Task {
                        await viewModel.proceed()
                    }
                }
                .disabled(!viewModel.canProceed || isBusy)
            }
        }
        .overlay {
            if isAwaitingInfoForAdding {
                LoadingOverlay(message: "Waiting for AnkiMobile...")
            }
        }
        .onOpenURL { url in
            guard isAwaitingInfoForAdding else { return }
            guard let expectedReturnURL, url == expectedReturnURL else { return }
            handleInfoForAddingReturn()
        }
    }

    private func requestInfoForAdding() {
        guard !isBusy else { return }
        Task { @MainActor in
            let returnURL = await AnkiMobileURLOpenerStore.shared.getReturnURL()
            guard let returnURL, let url = infoForAddingURL(returnURL: returnURL) else {
                handleRequestFailure(AnkiMobileInfoForAddingError.missingReturnURL)
                return
            }

            expectedReturnURL = returnURL
            isAwaitingInfoForAdding = true

            let opener = await AnkiMobileURLOpenerStore.shared.get()
            let opened: Bool
            if let opener {
                opened = await opener.open(url)
            } else {
                opened = await UIApplication.shared.open(url)
            }
            guard opened else {
                handleRequestFailure(AnkiMobileInfoForAddingError.openFailed)
                return
            }
        }
    }

    private func handleRequestFailure(_ error: Error) {
        isAwaitingInfoForAdding = false
        expectedReturnURL = nil
        viewModel.error = error
        viewModel.showError = true
    }

    private func infoForAddingURL(returnURL: URL) -> URL? {
        var components = URLComponents()
        components.scheme = "anki"
        components.host = "x-callback-url"
        components.path = "/infoForAdding"
        components.queryItems = [
            URLQueryItem(name: "x-success", value: returnURL.absoluteString),
        ]
        return components.url
    }

    private func handleInfoForAddingReturn() {
        isAwaitingInfoForAdding = false
        expectedReturnURL = nil

        let pasteboardType = "net.ankimobile.json"
        guard let data = UIPasteboard.general.data(forPasteboardType: pasteboardType) else {
            handleRequestFailure(AnkiMobileInfoForAddingError.missingClipboardData)
            return
        }

        UIPasteboard.general.setData(Data(), forPasteboardType: pasteboardType)
        viewModel.applyAnkiMobileInfoForAddingData(data)
    }
}

#Preview {
    NavigationStack {
        AnkiMobileSetupView(viewModel: AnkiConfigurationViewModel())
    }
}
