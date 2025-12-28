//
//  AnkiConfigurationFlowView.swift
//  MaruReader
//
//  Container for the multi-step Anki configuration flow.
//

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
            case .profileSelection:
                ProfileSelectionView(viewModel: viewModel)
            case .deckSelection:
                DeckSelectionView(viewModel: viewModel)
            case .modelSelection:
                ModelSelectionView(viewModel: viewModel)
            case .fieldMappingSelection:
                FieldMappingSelectionView(viewModel: viewModel)
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
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
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
