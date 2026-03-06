// AnkiMobileSetupView.swift
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
            String(localized: "Unable to build the return URL for AnkiMobile.")
        case .openFailed:
            String(localized: "Unable to open AnkiMobile.")
        case .missingClipboardData:
            String(localized: "AnkiMobile did not place infoForAdding data on the clipboard.")
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
                    Text(AppLocalization.loadedProfilesDecksModels(
                        profiles: viewModel.profiles.count,
                        decks: viewModel.decks.count,
                        models: viewModel.models.count
                    ))
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
                LoadingOverlay(message: String(localized: "Waiting for AnkiMobile..."))
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
            let opened: Bool = if let opener {
                await opener.open(url)
            } else {
                await UIApplication.shared.open(url)
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
