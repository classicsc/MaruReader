// UnifiedDictionaryManagementInProgressImportRow.swift
// MaruReader
// Copyright (c) 2026  Samuel Smoker
//
// MaruReader is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// MaruReader is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with MaruReader.  If not, see <http://www.gnu.org/licenses/>.

import SwiftUI

struct UnifiedDictionaryManagementInProgressImportRow: View {
    let item: UnifiedDictionaryManagementImportItem
    let onCancel: () -> Void

    private var statusIcon: String {
        item.isStarted ? "gear" : "clock"
    }

    private var statusColor: Color {
        item.isStarted ? .blue : .orange
    }

    private var statusMessage: String {
        if let message = item.displayProgressMessage, !message.isEmpty {
            return message
        }

        return item.isStarted ? String(localized: "Importing...") : String(localized: "Queued for import.")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .imageScale(.small)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: item.displayName)
                    .font(.headline)
                    .lineLimit(1)

                HStack(alignment: .center, spacing: 6) {
                    if item.isStarted {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 12)

            if item.canCancel {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
        .deleteDisabled(true)
        .moveDisabled(true)
    }
}
