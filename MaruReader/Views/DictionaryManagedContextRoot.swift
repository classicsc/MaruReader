// DictionaryManagedContextRoot.swift
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
import MaruDictionaryUICommon
import MaruReaderCore
import SwiftUI

struct DictionaryManagedContextRoot<Content: View>: View {
    let availability: DictionaryFeatureAvailability
    private let content: () -> Content

    init(
        availability: DictionaryFeatureAvailability = .ready,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.availability = availability
        self.content = content
    }

    var body: some View {
        switch availability {
        case .ready:
            content()
                .environment(\.managedObjectContext, DictionaryPersistenceController.shared.container.viewContext)
        case let .preparing(description):
            ProgressView(description)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .failed(message):
            ContentUnavailableView(
                "Dictionary Unavailable",
                systemImage: "character.book.closed.ja",
                description: Text(message)
            )
        @unknown default:
            content()
                .environment(\.managedObjectContext, DictionaryPersistenceController.shared.container.viewContext)
        }
    }
}
