//
//  DeckSelectionView.swift
//  MaruReader
//
//  Step 4: Select Anki deck.
//

import MaruAnki
import SwiftUI

struct DeckSelectionView: View {
    @Bindable var viewModel: AnkiConfigurationViewModel

    var body: some View {
        List(viewModel.decks, id: \.name, selection: $viewModel.selectedDeckName) { deck in
            Text(deck.name)
                .tag(deck.name)
                .contentShape(Rectangle())
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Select Deck")
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
        DeckSelectionView(viewModel: AnkiConfigurationViewModel())
    }
}
