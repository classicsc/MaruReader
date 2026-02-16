// DictionaryFormat.swift
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

/// Supported dictionary index formats.
enum DictionaryFormat: Int, Codable, Sendable, CustomStringConvertible {
    case v1 = 1
    case v3 = 3

    var description: String {
        "v\(rawValue)"
    }

    /// Derive a format from optional "format" and legacy "version" fields.
    /// Order of precedence matches existing logic: explicit format, then version.
    static func resolve(format: Int?, version: Int?) throws -> DictionaryFormat {
        if let f = format, let fmt = DictionaryFormat(rawValue: f) { return fmt }
        if let v = version, let fmt = DictionaryFormat(rawValue: v) { return fmt }
        throw DictionaryImportError.unsupportedFormat
    }
}
