//
//  AudioSourceListResponse.swift
//  MaruReader
//
//  JSON response model for audio sources that return a list of audio URLs.
//

import Foundation

/// Response from an audio source that returns a JSON list of audio URLs
struct AudioSourceListResponse: Decodable {
    let type: String
    let audioSources: [AudioSourceItem]

    struct AudioSourceItem: Decodable {
        let url: String
        let name: String?
    }
}
