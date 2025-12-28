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
    @State private var showingEditor = false
    @State private var editingProfile: FieldMappingProfileInfo?
    @State private var profileToDelete: FieldMappingProfileInfo?
    @State private var showDeleteConfirmation = false
    @State private var isLoading = true
    @State private var error: Error?
    @State private var showError = false

    var body: some View {
        List {
            if isLoading {
                ProgressView()
            } else {
                ForEach(viewModel.fieldMappingProfiles) { profile in
                    profileRow(profile)
                }
                .onDelete { indexSet in
                    if let index = indexSet.first {
                        let profile = viewModel.fieldMappingProfiles[index]
                        if !profile.isSystemProfile {
                            profileToDelete = profile
                            showDeleteConfirmation = true
                        }
                    }
                }
            }
        }
        .navigationTitle("Field Mappings")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editingProfile = nil
                    showingEditor = true
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
        .sheet(isPresented: $showingEditor, onDismiss: {
            Task {
                await loadProfiles()
            }
        }) {
            NavigationStack {
                FieldMappingEditorView(
                    viewModel: viewModel,
                    editingProfile: editingProfile
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
                showingEditor = true
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
