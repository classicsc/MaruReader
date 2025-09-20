//
//  DictionaryImportError.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/6/25.
//

enum DictionaryImportError: Error {
    case notADictionary
    case unsupportedFormat
    case importNotFound
    case dictionaryCreationFailed
    case invalidData
    case databaseError
    case fileAccessDenied
    case missingFile
    case noWorkingDirectory

    var localizedDescription: String {
        switch self {
        case .notADictionary:
            "The selected file is not a valid dictionary."
        case .unsupportedFormat:
            "The dictionary format is unsupported."
        case .importNotFound:
            "The import operation the component requested was not found."
        case .dictionaryCreationFailed:
            "A database error occurred."
        case .invalidData:
            "The dictionary contains invalid data."
        case .databaseError:
            "A database error occurred while importing the dictionary."
        case .fileAccessDenied:
            "Could not access the dictionary file."
        case .missingFile:
            "The dictionary file is missing."
        case .noWorkingDirectory:
            "No working directory is available."
        }
    }
}
