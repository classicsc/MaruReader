//
//  AnkiFieldMap.swift
//  MaruReader
//
//  Created by Sam Smoker on 12/17/25.
//

public struct AnkiFieldMap: Sendable, Codable {
    public let map: [String: [TemplateValue]]

    public init(map: [String: [TemplateValue]]) {
        self.map = map
    }
}
