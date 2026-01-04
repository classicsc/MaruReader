//
//  AnkiFieldValueFormatter.swift
//  MaruReader
//

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
