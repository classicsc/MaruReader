// ContextImageEncoderTests.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import Foundation
@testable import MaruReaderCore
import Testing

struct ContextImageEncoderTests {
    @Test func jpegData_fromPng_returnsJpegHeader() throws {
        let pngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO2aSZUAAAAASUVORK5CYII="
        let pngData = try #require(Data(base64Encoded: pngBase64))
        let jpegData = try #require(ContextImageEncoder.jpegData(from: pngData, quality: 0.9))

        #expect(jpegData.starts(with: [0xFF, 0xD8, 0xFF]))
    }

    @Test func jpegData_fromInvalidData_returnsNil() {
        let invalidData = Data([0x00, 0x01, 0x02])

        #expect(ContextImageEncoder.jpegData(from: invalidData, quality: 0.9) == nil)
    }
}
