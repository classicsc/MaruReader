// ImportErrorDescriptionTests.swift
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

import Foundation
@testable import MaruReaderCore
import Testing

/// Verify that import error types produce human-readable descriptions
/// when type-erased to `any Error`, not generic NSError text.
struct ImportErrorDescriptionTests {
    @Test func dictionaryImportError_localizedDescription_isReadable() {
        let error: any Error = DictionaryImportError.invalidData
        #expect(!error.localizedDescription.contains("DictionaryImportError"))
        #expect(error.localizedDescription == FrameworkLocalization.string("The dictionary contains invalid data."))
    }

    @Test func dictionaryImportError_allCases_haveReadableDescriptions() {
        let cases: [DictionaryImportError] = [
            .notADictionary,
            .unsupportedFormat,
            .importNotFound,
            .dictionaryCreationFailed,
            .invalidData,
            .databaseError,
            .fileAccessDenied,
            .missingFile,
            .deletionFailed,
            .mediaDirectoryCreationFailed,
        ]
        for error in cases {
            let erased: any Error = error
            #expect(
                !erased.localizedDescription.contains("DictionaryImportError"),
                "Case \(error) produced generic description: \(erased.localizedDescription)"
            )
        }
    }

    @Test func audioSourceImportError_localizedDescription_isReadable() {
        let error: any Error = AudioSourceImportError.invalidData
        #expect(!error.localizedDescription.contains("AudioSourceImportError"))
        #expect(error.localizedDescription == FrameworkLocalization.string("The audio source data is invalid."))
    }
}
