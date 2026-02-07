// GlossaryCompressionCodec.swift
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

enum GlossaryCompressionCodec {
    private static let compressedMagic = Data("MRG1".utf8)
    private static let uncompressedMagic = Data("MRG0".utf8)
    private static let jsonDecoder = JSONDecoder()

    static func encodeGlossaryJSON(_ jsonData: Data) -> Data {
        if let compressed = try? (jsonData as NSData).compressed(using: .lzfse) as Data {
            var payload = Data()
            payload.reserveCapacity(compressedMagic.count + compressed.count)
            payload.append(compressedMagic)
            payload.append(compressed)
            return payload
        }

        var payload = Data()
        payload.reserveCapacity(uncompressedMagic.count + jsonData.count)
        payload.append(uncompressedMagic)
        payload.append(jsonData)
        return payload
    }

    static func decodeGlossaryJSON(_ payload: Data?) -> Data? {
        guard let payload else {
            return nil
        }

        guard payload.count >= compressedMagic.count else {
            return nil
        }

        if payload.starts(with: compressedMagic) {
            let compressedPayload = Data(payload.dropFirst(compressedMagic.count))
            return try? (compressedPayload as NSData).decompressed(using: .lzfse) as Data
        }

        if payload.starts(with: uncompressedMagic) {
            return Data(payload.dropFirst(uncompressedMagic.count))
        }

        return nil
    }

    static func decodeDefinitions(from payload: Data?) -> [Definition]? {
        guard let glossaryJSON = decodeGlossaryJSON(payload) else {
            return nil
        }

        return try? jsonDecoder.decode([Definition].self, from: glossaryJSON)
    }
}
