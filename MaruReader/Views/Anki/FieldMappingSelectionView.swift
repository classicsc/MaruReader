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
    @State private var showingEditor = false

    var body: some View {
        List {
            Section {
                ForEach(viewModel.fieldMappingProfiles, id: \.id) { profile in
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
            }

            Section {
                Button {
                    showingEditor = true
                } label: {
                    Label("Create New Field Mapping", systemImage: "plus")
                }
            }
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
        .sheet(isPresented: $showingEditor, onDismiss: {
            Task {
                await viewModel.refreshFieldMappingProfiles()
            }
        }) {
            NavigationStack {
                FieldMappingEditorView(
                    viewModel: viewModel,
                    editingProfile: nil,
                    onSave: { newID in
                        viewModel.selectedFieldMappingProfileID = newID
                    }
                )
            }
        }
    }
}

#Preview {
    NavigationStack {
        FieldMappingSelectionView(viewModel: AnkiConfigurationViewModel())
    }
}
