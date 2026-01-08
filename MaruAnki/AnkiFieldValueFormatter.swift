// AnkiFieldValueFormatter.swift
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

enum AnkiFieldValueFormatter {
    static func buildFieldValues(from fields: [String: [TemplateResolvedValue]]) -> [String: String] {
        var output: [String: String] = [:]

        for (fieldName, values) in fields {
            var pieces: [String] = []

            for value in values {
                if let text = value.text, !text.isEmpty {
                    pieces.append(text)
                }

                let remoteMedia = value.mediaFiles.values.compactMap { url -> String? in
                    guard let scheme = url.scheme?.lowercased(),
                          scheme == "http" || scheme == "https"
                    else {
                        return nil
                    }
                    return url.absoluteString
                }

                pieces.append(contentsOf: remoteMedia)
            }

            output[fieldName] = pieces.joined(separator: "<br>")
        }

        return output
    }
}
