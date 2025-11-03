//
//  RubyText.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/2/25.
//

public struct RubyText: Sendable, Codable {
    let baseText: String
    let annotations: [RubyAnnotation]
}

public struct RubyAnnotation: Sendable, Codable {
    let text: String
    let range: Range<Int>
}
