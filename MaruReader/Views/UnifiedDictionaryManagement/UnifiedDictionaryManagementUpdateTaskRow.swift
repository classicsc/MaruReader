// UnifiedDictionaryManagementUpdateTaskRow.swift
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

import MaruDictionaryManagement
import MaruReaderCore
import SwiftUI

struct UnifiedDictionaryManagementUpdateTaskRow: View {
    let task: UnifiedDictionaryManagementUpdateTaskItem

    private var progressValue: Double? {
        guard task.totalBytes > 0 else { return nil }
        return Double(task.bytesReceived) / Double(task.totalBytes)
    }

    private var progressText: String? {
        guard task.totalBytes > 0 else { return nil }

        let received = task.bytesReceived.formatted(.byteCount(style: .file))
        let total = task.totalBytes.formatted(.byteCount(style: .file))
        return AppLocalization.progress(received: received, total: total)
    }

    private var statusMessage: String {
        if let message = task.displayProgressMessage, !message.isEmpty {
            return message
        }

        return task.isStarted ? String(localized: "Updating...") : String(localized: "Queued for update.")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(task.displayName)
                .font(.headline)
                .lineLimit(1)

            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let progressValue {
                ProgressView(value: progressValue)
            } else {
                ProgressView()
            }

            if let progressText {
                Text(progressText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .deleteDisabled(true)
        .moveDisabled(true)
    }
}
