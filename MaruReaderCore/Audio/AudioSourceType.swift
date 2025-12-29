//
//  AudioSourceType.swift
//  MaruReader
//
//  Created by Sam Smoker on 12/12/25.
//

import Foundation

public enum AudioSourceType: Sendable {
    /// URL pattern that returns audio file directly
    case urlPattern(String)
    /// URL pattern that returns a JSON audio source list
    case jsonListPattern(String)
    /// Indexed source with local or remote audio files
    case indexed(UUID)
}
