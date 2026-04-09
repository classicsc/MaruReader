// UnifiedDictionaryManagementRankingPicker.swift
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
import MaruDictionaryManagement
import MaruReaderCore
import SwiftUI

struct UnifiedDictionaryManagementRankingPicker: View {
    let title: LocalizedStringKey
    let dictionaries: [Dictionary]
    let enabledKey: ReferenceWritableKeyPath<Dictionary, Bool>
    let onSelectionChange: (NSManagedObjectID?) -> Void

    @State private var selectedID: NSManagedObjectID?

    private var currentSelectionID: NSManagedObjectID? {
        dictionaries.first(where: { $0[keyPath: enabledKey] })?.objectID
    }

    private var selectionSyncToken: String {
        dictionaries.map { dictionary in
            "\(dictionary.objectID.uriRepresentation().absoluteString):\(dictionary[keyPath: enabledKey])"
        }
        .joined(separator: "|")
    }

    var body: some View {
        Picker(title, selection: $selectedID) {
            ForEach(dictionaries, id: \.objectID) { dictionary in
                Text(dictionary.title ?? AppLocalization.unknownDictionary)
                    .tag(dictionary.objectID as NSManagedObjectID?)
            }
        }
        .task(id: selectionSyncToken) {
            selectedID = currentSelectionID
        }
        .onChange(of: selectedID) { _, newValue in
            guard newValue != currentSelectionID else { return }
            onSelectionChange(newValue)
        }
    }
}
