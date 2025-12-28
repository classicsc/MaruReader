//
//  ConnectionTypeSelectionView.swift
//  MaruReader
//
//  Step 1: Select connection type (currently only Anki-Connect).
//

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
                Text("Choose how to connect to Anki. Anki-Connect requires the Anki-Connect add-on installed in Anki.")
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
            "Connect to Anki running on your computer via the Anki-Connect add-on"
        }
    }
}

#Preview {
    NavigationStack {
        ConnectionTypeSelectionView(viewModel: AnkiConfigurationViewModel())
    }
}
