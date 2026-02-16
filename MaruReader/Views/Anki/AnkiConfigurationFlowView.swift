// AnkiConfigurationFlowView.swift
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

struct AnkiConfigurationFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AnkiConfigurationViewModel()

    var body: some View {
        Group {
            switch viewModel.currentStep {
            case .connectionType:
                ConnectionTypeSelectionView(viewModel: viewModel)
            case .connectionDetails:
                AnkiConnectSetupView(viewModel: viewModel)
            case .mobileDetails:
                AnkiMobileSetupView(viewModel: viewModel)
            case .profileSelection:
                ProfileSelectionView(viewModel: viewModel)
            case .deckSelection:
                DeckSelectionView(viewModel: viewModel)
            case .modelSelection:
                ModelSelectionView(viewModel: viewModel)
            case .fieldMappingSelection:
                FieldMappingSelectionView(viewModel: viewModel)
            case .duplicateSettings:
                DuplicateSettingsView(viewModel: viewModel)
            case .templateConfiguration:
                TemplateConfigurationView(viewModel: viewModel)
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.showError = false
            }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
        .toolbar {
            if viewModel.canGoBack {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") {
                        viewModel.goBack()
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(viewModel.isLoading)
            }
        }
        .interactiveDismissDisabled(viewModel.isLoading)
        .onAppear {
            viewModel.onComplete = {
                dismiss()
            }
        }
    }
}

#Preview {
    NavigationStack {
        AnkiConfigurationFlowView()
    }
}
