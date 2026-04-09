// UnifiedDictionaryManagementFailedImportRow.swift
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

struct UnifiedDictionaryManagementFailedImportRow: View {
    let item: UnifiedDictionaryManagementImportItem
    let onRemove: () -> Void

    private var statusIcon: String {
        item.isCancelled ? "xmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    private var statusColor: Color {
        item.isCancelled ? .secondary : .red
    }

    private var statusMessage: String {
        if item.isCancelled {
            return String(localized: "Import cancelled.")
        }

        return item.errorMessage ?? item.displayProgressMessage ?? String(localized: "Import failed.")
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

                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(statusColor)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Button("Remove", action: onRemove)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.vertical, 2)
        .deleteDisabled(true)
        .moveDisabled(true)
    }
}
