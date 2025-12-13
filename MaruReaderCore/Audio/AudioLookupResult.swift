//
//  AudioLookupResult.swift
//  MaruReader
//
//  Created by Sam Smoker on 12/12/25.
//

import Foundation

public struct AudioLookupResult: Sendable {
    public let request: AudioLookupRequest
    public let sources: [AudioSourceResult]

    public var hasAudio: Bool { !sources.isEmpty }
    public var primaryAudioURL: URL? { sources.first?.url }

    public init(request: AudioLookupRequest, sources: [AudioSourceResult]) {
        self.request = request
        self.sources = sources
    }
}

public struct AudioSourceResult: Sendable {
    public let url: URL
    public let sourceName: String
    public let sourceType: AudioSourceType
    public let isLocal: Bool
    /// The pitch accent downstep position this audio represents (e.g., "0", "1", "2-1"), or nil if unknown
    public let pitchNumber: String?

    public init(url: URL, sourceName: String, sourceType: AudioSourceType, isLocal: Bool, pitchNumber: String? = nil) {
        self.url = url
        self.sourceName = sourceName
        self.sourceType = sourceType
        self.isLocal = isLocal
        self.pitchNumber = pitchNumber
    }
}
