//
//  AnkiMobileSetupView.swift
//  MaruReader
//
//  Step 2: Configure AnkiMobile profile, deck, and note type.
//

import SwiftUI

struct AnkiMobileSetupView: View {
    @Bindable var viewModel: AnkiConfigurationViewModel

    var body: some View {
        Form {
            Section("AnkiMobile Settings") {
                TextField("Profile (optional)", text: $viewModel.mobileProfileName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Deck", text: $viewModel.mobileDeckName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Note Type", text: $viewModel.mobileModelName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter names exactly as they appear in AnkiMobile.")
                    Text("Profile is optional and only needed if you want to target a specific profile.")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
        .navigationTitle("AnkiMobile")
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
        AnkiMobileSetupView(viewModel: AnkiConfigurationViewModel())
    }
}
