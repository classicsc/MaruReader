//
//  BookReaderError.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/5/25.
//

import Foundation

enum BookReaderError: LocalizedError {
    case bookFileNotFound
    case cannotAccessAppSupport
    case invalidBookPath
    case unknownError

    var errorDescription: String? {
        switch self {
        case .bookFileNotFound:
            "Book file not found"
        case .cannotAccessAppSupport:
            "Cannot access application support directory"
        case .invalidBookPath:
            "Invalid book file path"
        case .unknownError:
            "An unknown error occurred"
        }
    }
}
