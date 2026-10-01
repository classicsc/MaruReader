// MangaFilePickerModeTests.swift
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
@testable import MaruManga
import Testing
import UniformTypeIdentifiers

struct MangaFilePickerModeTests {
    @Test func importArchive_allowsZipAndCBZ() throws {
        let types = MangaFilePickerMode.importArchive.allowedContentTypes

        #expect(types.contains(.zip))
        #expect(try types.contains(#require(UTType(filenameExtension: "cbz"))))
        #expect(try !types.contains(#require(UTType(filenameExtension: "mokuro"))))
    }

    @Test func attachMokuro_allowsOnlyMokuro() throws {
        let types = MangaFilePickerMode.attachMokuro.allowedContentTypes

        #expect(try types == [#require(UTType(filenameExtension: "mokuro"))])
        #expect(!types.contains(.zip))
    }

    @Test func modes_haveDistinctContentTypes() {
        #expect(
            MangaFilePickerMode.importArchive.allowedContentTypes
                != MangaFilePickerMode.attachMokuro.allowedContentTypes,
            "The two picker modes must not resolve to the same content types, or one flow would filter for the wrong file kind"
        )
    }
}
