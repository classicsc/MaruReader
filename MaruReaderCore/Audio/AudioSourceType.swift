//
//  AudioSourceType.swift
//  MaruReader
//
//  Created by Sam Smoker on 12/12/25.
//

import Foundation

public enum AudioSourceType: Sendable {
    case urlPattern(String)
    case indexed(UUID)
}
