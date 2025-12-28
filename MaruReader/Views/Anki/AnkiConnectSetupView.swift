//
//  AnkiConnectSetupView.swift
//  MaruReader
//
//  Step 2: Configure Anki-Connect host, port, and API key.
//

import SwiftUI

struct AnkiConnectSetupView: View {
    @Bindable var viewModel: AnkiConfigurationViewModel

    var body: some View {
        Form {
            Section("Server Connection") {
                TextField("Host", text: $viewModel.host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                TextField("Port", text: $viewModel.port)
                    .keyboardType(.numberPad)

                SecureField("API Key (optional)", text: $viewModel.apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Make sure Anki is running on your computer with the Anki-Connect add-on installed.")
                    Text("Default settings: localhost:8765")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
        .navigationTitle("Connection Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Test Connection") {
                    Task {
                        await viewModel.proceed()
                    }
                }
                .disabled(!viewModel.canProceed || viewModel.isLoading)
            }
        }
        .overlay {
            if viewModel.isLoading {
                LoadingOverlay(message: "Testing connection...")
            }
        }
    }
}

struct LoadingOverlay: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .background(.regularMaterial)
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        AnkiConnectSetupView(viewModel: AnkiConfigurationViewModel())
    }
}
