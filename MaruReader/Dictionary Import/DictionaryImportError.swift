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
}
