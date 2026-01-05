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

    /// Profiles that should be shown (non-hidden)
    private var visibleProfiles: [FieldMappingProfileInfo] {
        viewModel.fieldMappingProfiles.filter { !$0.isHidden }
    }

    var body: some View {
        List {
            // Templates section
            Section {
                ForEach(ConfigurableProfileTemplates.all) { template in
                    Button {
                        viewModel.selectTemplate(template.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.displayName)
                                    .foregroundStyle(.primary)
                                if viewModel.templateConfiguredProfiles[template.id] == true {
                                    Text("Configured")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                } else {
                                    Text("Configurable Template")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if viewModel.selectedTemplateID == template.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Templates")
            }

            // Saved profiles section
            Section {
                ForEach(visibleProfiles, id: \.id) { profile in
                    Button {
                        viewModel.clearTemplateSelection()
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
                            if viewModel.selectedFieldMappingProfileID == profile.id, viewModel.selectedTemplateID == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Saved Profiles")
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
                Button(viewModel.selectedTemplateID != nil ? "Next" : "Save") {
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
