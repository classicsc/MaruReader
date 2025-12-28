//
//  ProfileSelectionView.swift
//  MaruReader
//
//  Step 3: Select Anki profile.
//

import MaruAnki
import SwiftUI

struct ProfileSelectionView: View {
    @Bindable var viewModel: AnkiConfigurationViewModel

    var body: some View {
        List(viewModel.profiles, id: \.id, selection: $viewModel.selectedProfileID) { profile in
            HStack {
                Text(profile.id)
                Spacer()
                if profile.isActiveProfile {
                    Text("Active")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .cornerRadius(4)
                }
            }
            .tag(profile.id)
            .contentShape(Rectangle())
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Select Profile")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Next") {
                    Task {
                        await viewModel.proceed()
                    }
                }
                .disabled(!viewModel.canProceed || viewModel.isLoading)
            }
        }
        .overlay {
            if viewModel.isLoading {
                LoadingOverlay(message: "Loading decks and models...")
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileSelectionView(viewModel: AnkiConfigurationViewModel())
    }
}
