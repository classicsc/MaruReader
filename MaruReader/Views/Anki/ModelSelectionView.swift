// ModelSelectionView.swift
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
