// ProfileSelectionView.swift
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
