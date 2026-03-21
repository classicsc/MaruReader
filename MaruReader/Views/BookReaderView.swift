// BookReaderView.swift
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

import CoreData
import SwiftUI

struct BookReaderView: View {
    @ScaledMetric(relativeTo: .body) private var floatingButtonIconSize: CGFloat = 15
    @ScaledMetric(relativeTo: .body) private var floatingButtonFrameSize: CGFloat = 44

    private let bookID: NSManagedObjectID
    private let persistenceController: BookDataPersistenceController
    @State private var featureState: BookReaderFeatureState?
    private let onDismissOverride: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    init(
        bookID: NSManagedObjectID,
        persistenceController: BookDataPersistenceController = .shared,
        onDismiss: (() -> Void)? = nil
    ) {
        self.bookID = bookID
        self.persistenceController = persistenceController
        onDismissOverride = onDismiss
    }

    var body: some View {
        Group {
            if let featureState {
                switch featureState.session.phase {
                case .loading:
                    ProgressView("Loading book...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case let .error(error):
                    BookReaderErrorView(
                        error: error,
                        floatingButtonIconSize: floatingButtonIconSize,
                        floatingButtonFrameSize: floatingButtonFrameSize,
                        onDismiss: dismissReader
                    )
                case .reading:
                    BookReaderContentView(
                        session: featureState.session,
                        chrome: featureState.chrome,
                        bookmarks: featureState.bookmarks,
                        lookup: featureState.lookup,
                        readerPreferences: featureState.readerPreferences,
                        onDismiss: dismissReader
                    )
                }
            } else {
                ProgressView("Loading book...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await initializeFeatureStateIfNeeded()
        }
    }

    private func dismissReader() {
        if let onDismissOverride {
            onDismissOverride()
        } else {
            dismiss()
        }
    }

    private func initializeFeatureStateIfNeeded() async {
        guard featureState == nil else { return }

        let featureState = BookReaderFeatureState(
            bookID: bookID,
            persistenceController: persistenceController
        )
        self.featureState = featureState
        await featureState.session.startIfNeeded()
    }
}
