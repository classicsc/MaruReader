//
//  FieldMappingManagementView.swift
//  MaruReader
//
//  Management view for field mapping profiles with create, edit, delete functionality.
//

import MaruAnki
import SwiftUI

struct FieldMappingManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AnkiConfigurationViewModel()
    @State private var showingNewEditor = false
    @State private var editingProfile: FieldMappingProfileInfo?
    @State private var configuringTemplate: ConfigurableProfileTemplate?
    @State private var profileToDelete: FieldMappingProfileInfo?
    @State private var showDeleteConfirmation = false
    @State private var isLoading = true
    @State private var error: Error?
    @State private var showError = false

    /// Visible profiles (non-hidden, non-system)
    private var customProfiles: [FieldMappingProfileInfo] {
        viewModel.fieldMappingProfiles.filter { !$0.isHidden && !$0.isSystemProfile }
    }

    /// System profiles
    private var systemProfiles: [FieldMappingProfileInfo] {
        viewModel.fieldMappingProfiles.filter(\.isSystemProfile)
    }

    var body: some View {
        List {
            if isLoading {
                ProgressView()
            } else {
                // Templates section
                Section {
                    ForEach(ConfigurableProfileTemplates.all) { template in
                        templateRow(template)
                    }
                } header: {
                    Text("Templates")
                }

                // Custom profiles section
                if !customProfiles.isEmpty {
                    Section {
                        ForEach(customProfiles) { profile in
                            profileRow(profile)
                        }
                        .onDelete { indexSet in
                            if let index = indexSet.first {
                                let profile = customProfiles[index]
                                profileToDelete = profile
                                showDeleteConfirmation = true
                            }
                        }
                    } header: {
                        Text("Custom Profiles")
                    }
                }

                // System profiles section
                Section {
                    ForEach(systemProfiles) { profile in
                        profileRow(profile)
                    }
                } header: {
                    Text("System Profiles")
                }
            }
        }
        .navigationTitle("Field Mappings")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await loadProfiles()
        }
        .refreshable {
            await loadProfiles()
        }
        .sheet(isPresented: $showingNewEditor, onDismiss: {
            Task {
                await loadProfiles()
            }
        }) {
            NavigationStack {
                FieldMappingEditorView(
                    viewModel: viewModel,
                    editingProfile: nil
                )
            }
        }
        .sheet(item: $editingProfile, onDismiss: {
            Task {
                await loadProfiles()
            }
        }) { profile in
            NavigationStack {
                FieldMappingEditorView(
                    viewModel: viewModel,
                    editingProfile: profile
                )
            }
        }
        .sheet(item: $configuringTemplate, onDismiss: {
            Task {
                await loadProfiles()
            }
        }) { template in
            NavigationStack {
                TemplateConfigurationSheetView(
                    template: template,
                    onSave: {
                        configuringTemplate = nil
                        Task {
                            await loadProfiles()
                        }
                    }
                )
            }
        }
        .confirmationDialog(
            "Delete Field Mapping",
            isPresented: $showDeleteConfirmation,
            presenting: profileToDelete
        ) { profile in
            Button("Delete", role: .destructive) {
                Task {
                    await deleteProfile(profile)
                }
            }
        } message: { profile in
            Text("Are you sure you want to delete \"\(profile.displayName)\"? This cannot be undone.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            if let error {
                Text(error.localizedDescription)
            }
        }
    }

    @ViewBuilder
    private func profileRow(_ profile: FieldMappingProfileInfo) -> some View {
        Button {
            if !profile.isSystemProfile {
                editingProfile = profile
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.displayName)
                        .foregroundStyle(.primary)
                    if profile.isSystemProfile {
                        Text("System Profile")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let fieldMap = profile.fieldMap {
                        Text("\(fieldMap.map.count) fields")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !profile.isSystemProfile {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .deleteDisabled(profile.isSystemProfile)
    }

    @ViewBuilder
    private func templateRow(_ template: ConfigurableProfileTemplate) -> some View {
        Button {
            configuringTemplate = template
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
                        Text("Not configured")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func loadProfiles() async {
        isLoading = true
        await viewModel.refreshFieldMappingProfiles()
        isLoading = false
    }

    private func deleteProfile(_ profile: FieldMappingProfileInfo) async {
        do {
            try await viewModel.deleteFieldMappingProfile(id: profile.id)
        } catch {
            self.error = error
            self.showError = true
        }
    }
}

#Preview {
    NavigationStack {
        FieldMappingManagementView()
    }
}
