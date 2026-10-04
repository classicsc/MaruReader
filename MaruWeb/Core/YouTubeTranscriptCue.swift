// YouTubeTranscriptCue.swift
// MaruReader
// Copyright (c) 2026  Samuel Smoker
//
// MaruReader is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// MaruReader is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with MaruReader.  If not, see <http://www.gnu.org/licenses/>.

import Foundation

struct YouTubeTranscriptCue: Codable, Identifiable, Equatable {
    let id: Int
    let start: Double
    let text: String

    static func activeID(in cues: [Self], at time: Double) -> Int? {
        // Upper-bound search also handles seeking backwards and equal timestamps.
        var lower = 0
        var upper = cues.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if cues[middle].start <= time {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower > 0 ? cues[lower - 1].id : nil
    }

    func characterOffset(forUTF16Offset offset: Int) -> Int? {
        Self.characterOffset(in: text, forUTF16Offset: offset)
    }

    static func characterOffset(in text: String, forUTF16Offset offset: Int) -> Int? {
        guard offset >= 0 else { return nil }
        var utf16Offset = 0
        for (index, character) in text.enumerated() {
            utf16Offset += String(character).utf16.count
            if offset < utf16Offset {
                return index
            }
        }
        return nil
    }

    var timestamp: String {
        let seconds = Int(start)
        return seconds >= 3600
            ? String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
            : String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
