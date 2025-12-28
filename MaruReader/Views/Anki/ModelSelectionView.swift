//
//  ModelSelectionView.swift
//  MaruReader
//
//  Step 5: Select Anki note type (model).
//

import MaruAnki
import SwiftUI

struct ModelSelectionView: View {
    @Bindable var viewModel: AnkiConfigurationViewModel

    var body: some View {
        List(viewModel.models, id: \.name, selection: $viewModel.selectedModelName) { model in
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                Text(model.fields.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .tag(model.name)
            .contentShape(Rectangle())
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Select Note Type")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Next") {
                    Task {
                        await viewModel.proceed()
                    }
                }
                .disabled(!viewModel.canProceed)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ModelSelectionView(viewModel: AnkiConfigurationViewModel())
    }
}
