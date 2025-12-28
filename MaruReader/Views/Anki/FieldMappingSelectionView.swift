//
//  FieldMappingSelectionView.swift
//  MaruReader
//
//  Step 6: Select field mapping profile.
//

import MaruAnki
import SwiftUI

struct FieldMappingSelectionView: View {
    @Bindable var viewModel: AnkiConfigurationViewModel

    var body: some View {
        List(viewModel.fieldMappingProfiles, id: \.id) { profile in
            Button {
                viewModel.selectedFieldMappingProfileID = profile.id
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.displayName)
                            .foregroundStyle(.primary)
                        if profile.isSystemProfile {
                            Text("System Profile")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if viewModel.selectedFieldMappingProfileID == profile.id {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Field Mapping")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await viewModel.proceed()
                    }
                }
                .disabled(!viewModel.canProceed || viewModel.isLoading)
            }
        }
        .overlay {
            if viewModel.isLoading {
                LoadingOverlay(message: "Saving configuration...")
            }
        }
    }
}

#Preview {
    NavigationStack {
        FieldMappingSelectionView(viewModel: AnkiConfigurationViewModel())
    }
}
