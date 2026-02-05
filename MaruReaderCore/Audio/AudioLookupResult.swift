// AudioLookupResult.swift
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

struct AudioLookupResult: Sendable {
    let request: AudioLookupRequest
    let sources: [AudioSourceResult]

    var hasAudio: Bool {
        !sources.isEmpty
    }

    var primaryAudioURL: URL? {
        sources.first?.url
    }
}

struct AudioSourceResult: Sendable {
    let url: URL
    /// The name of the audio source item (from JSON response), or provider name if no specific item name
    let sourceName: String
    /// The name of the audio provider/dictionary (always the provider name)
    let providerName: String
    let sourceType: AudioSourceType
    let isLocal: Bool
    /// The pitch accent downstep position this audio represents (e.g., "0", "1", "2-1"), or nil if unknown
    let pitchNumber: String?

    init(
        url: URL,
        sourceName: String,
        providerName: String,
        sourceType: AudioSourceType,
        isLocal: Bool,
        pitchNumber: String? = nil
    ) {
        self.url = url
        self.sourceName = sourceName
        self.providerName = providerName
        self.sourceType = sourceType
        self.isLocal = isLocal
        self.pitchNumber = pitchNumber
    }
}
