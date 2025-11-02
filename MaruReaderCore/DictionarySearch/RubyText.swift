//
//  RubyText.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/2/25.
//

public struct RubyText: Codable, Sendable {
    public let baseText: String
    public let annotations: [RubyAnnotation]
}

public struct RubyAnnotation: Codable, Sendable {
    public let text: String
    public let range: Range<Int>
}
