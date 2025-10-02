//
//  RubyText.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/2/25.
//

struct RubyText: Codable {
    let baseText: String
    let annotations: [RubyAnnotation]
}

struct RubyAnnotation: Codable {
    let text: String
    let range: Range<Int>
}
