// ConnectionTypeSelectionView.swift
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

struct ConnectionTypeSelectionView: View {
    @Bindable var viewModel: AnkiConfigurationViewModel

    var body: some View {
        Form {
            Section {
                ForEach(AnkiConfigurationViewModel.ConnectionType.allCases) { type in
                    Button {
                        viewModel.connectionType = type
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(type.rawValue)
                                    .foregroundStyle(.primary)
                                Text(connectionTypeDescription(type))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if viewModel.connectionType == type {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Connection Type")
            } footer: {
                Text("Choose how to connect to Anki. AnkiMobile works with the Anki app on your device; Anki-Connect works with the addon on your computer.")
            }
        }
        .navigationTitle("Connect to Anki")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Next") {
                    Task {
                        await viewModel.proceed()
                    }
                }
            }
        }
    }

    private func connectionTypeDescription(_ type: AnkiConfigurationViewModel.ConnectionType) -> String {
        switch type {
        case .ankiConnect:
            "Advanced: Connect to Anki running on your computer via the Anki-Connect add-on. Requires Anki open with the addon installed, and a valid SSL certificate."
        case .ankiMobile:
            "Add notes to AnkiMobile on this device. Easy to set up, but notes will not contain images embedded in dictionary definitions, local audio, or context media like book cover images and content screenshots."
        }
    }
}

#Preview {
    NavigationStack {
        ConnectionTypeSelectionView(viewModel: AnkiConfigurationViewModel())
    }
}
