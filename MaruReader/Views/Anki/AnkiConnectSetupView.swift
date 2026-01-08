// AnkiConnectSetupView.swift
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
