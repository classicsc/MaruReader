// PitchAccentCategoryCalculator.swift
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

public enum PitchAccentCategory: String, Sendable {
    case heiban
    case atamadaka
    case nakadaka
    case odaka
    case kifuku
}

public struct PitchAccentCategoryCalculator: Sendable {
    public static func moraCount(for reading: String) -> Int {
        guard !reading.isEmpty else { return 0 }

        let smallKana: Set<Character> = [
            "ゃ", "ゅ", "ょ", "ャ", "ュ", "ョ",
            "ぁ", "ぃ", "ぅ", "ぇ", "ぉ",
            "ァ", "ィ", "ゥ", "ェ", "ォ",
        ]

        var count = 0
        var index = reading.startIndex
        while index < reading.endIndex {
            let nextIndex = reading.index(after: index)
            if nextIndex < reading.endIndex, smallKana.contains(reading[nextIndex]) {
                count += 1
                index = reading.index(after: nextIndex)
                continue
            }
            count += 1
            index = nextIndex
        }

        return count
    }

    public static func downstepPosition(for pitchAccent: PitchAccent) -> Int? {
        downstepPosition(for: pitchAccent.position)
    }

    public static func downstepPosition(for position: PitchAccent.PitchPosition) -> Int? {
        switch position {
        case let .mora(value):
            value
        case let .pattern(pattern):
            downstepPosition(forPattern: pattern)
        }
    }

    public static func category(
        reading: String,
        position: PitchAccent.PitchPosition,
        isVerbOrAdjective: Bool
    ) -> PitchAccentCategory? {
        guard let downstep = downstepPosition(for: position) else {
            return nil
        }
        if downstep == 0 {
            return .heiban
        }
        if isVerbOrAdjective {
            return downstep > 0 ? .kifuku : nil
        }
        if downstep == 1 {
            return .atamadaka
        }
        if downstep > 1 {
            let moraTotal = moraCount(for: reading)
            guard moraTotal > 0 else { return nil }
            return downstep >= moraTotal ? .odaka : .nakadaka
        }
        return nil
    }

    public static func categories(for group: GroupedSearchResults) -> [PitchAccentCategory] {
        let reading = (group.reading?.isEmpty == false) ? (group.reading ?? "") : group.expression
        let posTags = group.termTags
            .filter { $0.normalizedCategory == .partOfSpeech }
            .map(\.name)

        let isVerbOrAdjective: Bool
        if !posTags.isEmpty {
            isVerbOrAdjective = isNonNounVerbOrAdjective(tags: posTags)
        } else {
            let pitchTags = group.pitchAccentResults
                .flatMap(\.pitches)
                .flatMap { $0.tags ?? [] }
            isVerbOrAdjective = !pitchTags.isEmpty && isNonNounVerbOrAdjective(tags: pitchTags)
        }

        var seen = Set<PitchAccentCategory>()
        var results: [PitchAccentCategory] = []

        for pitchResult in group.pitchAccentResults {
            for pitch in pitchResult.pitches {
                guard let category = category(
                    reading: reading,
                    position: pitch.position,
                    isVerbOrAdjective: isVerbOrAdjective
                ) else {
                    continue
                }
                if seen.insert(category).inserted {
                    results.append(category)
                }
            }
        }

        return results
    }

    private static func downstepPosition(forPattern pattern: String) -> Int? {
        guard !pattern.isEmpty else { return nil }
        let chars = Array(pattern.uppercased())
        for i in 0 ..< (chars.count - 1) {
            if chars[i] == "H", chars[i + 1] == "L" {
                return i + 1
            }
        }
        if chars.first == "L" {
            return 0
        }
        return nil
    }

    private static func isNonNounVerbOrAdjective(tags: [String]) -> Bool {
        var isVerbOrAdjective = false
        var isSuruVerb = false
        var isNoun = false

        for tag in tags {
            let normalized = tag.lowercased()
            switch normalized {
            case "v1", "vk", "vz", "adj-i":
                isVerbOrAdjective = true
            case "v5":
                isVerbOrAdjective = true
            case "vs":
                isVerbOrAdjective = true
                isSuruVerb = true
            case "n":
                isNoun = true
            default:
                if normalized.hasPrefix("v5") {
                    isVerbOrAdjective = true
                } else if normalized.hasPrefix("vs") {
                    isVerbOrAdjective = true
                    isSuruVerb = true
                }
            }
        }

        return isVerbOrAdjective && !(isSuruVerb && isNoun)
    }
}
