//
//  DictionaryImportInfo.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/1/25.
//

import Foundation

/// Represents information about a dictionary import operation.
struct DictionaryImportInfo {
    /// The display name of the dictionary.
    let displayName: String

    /// The file URL of the dictionary to be imported.
    let zipFileURL: URL?

    /// A unique identifier for the import operation.
    let id: UUID

    /// The type of import being performed.
    let importType: DictionaryImportType

    /// The time the import was initiated.
    let timestamp: Date = .init()

    /// The time the import was completed.
    var completionTime: Date?

    /// Initialize a new import info instance for a file URL source.
    init(displayName: String, id: UUID, zipFileURL: URL) {
        self.displayName = displayName
        self.zipFileURL = zipFileURL
        self.id = id
        self.importType = .zipFile
    }
}

enum DictionaryImportType {
    case zipFile
}
