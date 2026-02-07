// FieldMappingSelectionView.swift
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

struct FieldMappingSelectionView: View {
    @Bindable var viewModel: AnkiConfigurationViewModel
    @State private var showingEditor = false

    /// Profiles that should be shown during setup (non-hidden and compatible with selected note type).
    private var compatibleProfiles: [FieldMappingProfileInfo] {
        viewModel.compatibleVisibleFieldMappingProfiles
    }

    var body: some View {
        List {
            templatesSection
            savedProfilesSection
            createProfileSection
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
                    setupFieldNames: viewModel.selectedModel?.fields,
                    onSave: { newID in
                        viewModel.selectedFieldMappingProfileID = newID
                    }
                )
            }
        }
    }

    private var templatesSection: some View {
        Section("Templates") {
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
        }
    }

    private var savedProfilesSection: some View {
        Section {
            if compatibleProfiles.isEmpty {
                Text("No compatible field mappings for this note type.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(compatibleProfiles, id: \.id) { profile in
                    profileButton(profile)
                }
            }
        } header: {
            Text("Saved Profiles")
        } footer: {
            Text("Only profiles with field names that exist in the selected note type are shown.")
        }
    }

    private var createProfileSection: some View {
        Section {
            Button {
                showingEditor = true
            } label: {
                Label("Create New Field Mapping", systemImage: "plus")
            }
        }
    }

    private func profileButton(_ profile: FieldMappingProfileInfo) -> some View {
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
}

#Preview {
    NavigationStack {
        FieldMappingSelectionView(viewModel: AnkiConfigurationViewModel())
    }
}
