//
//  AudioLookupRequest.swift
//  MaruReader
//
//  Created by Sam Smoker on 12/12/25.
//

public struct AudioLookupRequest: Sendable {
    public let term: String
    public let reading: String?
    public let downstepPosition: String? // e.g. "0" for no downstep, "3" for downstep after 3rd mora, "1-1-1" for compound patterns
    public let language: String

    public init(term: String, reading: String?, downstepPosition: String?, language: String = "ja") {
        self.term = term
        self.reading = reading
        self.language = language
        self.downstepPosition = downstepPosition
    }
}
