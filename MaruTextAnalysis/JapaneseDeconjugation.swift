// JapaneseDeconjugation.swift
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

public struct JapaneseDeconjugationCandidate: Sendable, Hashable {
    public let text: String
    public let originalText: String
    public let tags: [String]
    public let process: [String]
    public let priority: Int

    public init(text: String, originalText: String, tags: [String], process: [String], priority: Int) {
        self.text = text
        self.originalText = originalText
        self.tags = tags
        self.process = process
        self.priority = priority
    }
}

struct JapaneseDeconjugationRule {
    let type: String
    let contextRule: String?
    let decEnd: String
    let conEnd: String
    let decTag: String?
    let conTag: String?
    let detail: String
    let ordinal: Int
}

private struct JapaneseDeconjugationForm: Hashable {
    let text: String
    let originalText: String
    let tags: [String]
    let seenText: Set<String>
    let process: [String]
}

public enum JapaneseDeconjugator {
    public static func deconjugate(_ text: String, maxCandidates: Int = 128) -> [JapaneseDeconjugationCandidate] {
        guard !text.isEmpty, maxCandidates > 0 else { return [] }

        var processed = Set<JapaneseDeconjugationForm>(minimumCapacity: min(text.count * 2, 100))
        var novel: Set<JapaneseDeconjugationForm> = [
            JapaneseDeconjugationForm(text: text, originalText: text, tags: [], seenText: [], process: []),
        ]

        while !novel.isEmpty, processed.count < maxCandidates {
            var newNovel = Set<JapaneseDeconjugationForm>(minimumCapacity: novel.count * 2)

            for form in novel {
                if shouldSkip(form) {
                    continue
                }

                for rule in JapaneseDeconjugationRule.generated {
                    guard let newForm = apply(rule, to: form) else {
                        continue
                    }
                    if !processed.contains(newForm), !novel.contains(newForm), !newNovel.contains(newForm) {
                        newNovel.insert(newForm)
                    }
                }
            }

            processed.formUnion(novel)
            novel = newNovel
        }

        return processed
            .map { form in
                JapaneseDeconjugationCandidate(
                    text: form.text,
                    originalText: form.originalText,
                    tags: form.tags,
                    process: form.process,
                    priority: form.process.count
                )
            }
            .sorted { lhs, rhs in
                if lhs.process.isEmpty != rhs.process.isEmpty {
                    return lhs.process.isEmpty
                }
                if lhs.priority != rhs.priority {
                    return lhs.priority < rhs.priority
                }
                if lhs.text.count != rhs.text.count {
                    return lhs.text.count > rhs.text.count
                }
                if lhs.text != rhs.text {
                    return lhs.text < rhs.text
                }
                if lhs.tags != rhs.tags {
                    return lhs.tags.lexicographicallyPrecedes(rhs.tags)
                }
                return lhs.process.lexicographicallyPrecedes(rhs.process)
            }
            .prefix(maxCandidates)
            .map(\.self)
    }

    private static func apply(_ rule: JapaneseDeconjugationRule, to form: JapaneseDeconjugationForm) -> JapaneseDeconjugationForm? {
        switch rule.type {
        case "stdrule":
            return standardRuleDeconjugate(form, rule)
        case "rewriterule":
            return form.text == rule.conEnd ? standardRuleDeconjugate(form, rule) : nil
        case "onlyfinalrule":
            return form.tags.isEmpty ? standardRuleDeconjugate(form, rule) : nil
        case "neverfinalrule":
            return form.tags.isEmpty ? nil : standardRuleDeconjugate(form, rule)
        case "contextrule":
            guard contextRuleMatches(form, rule) else { return nil }
            return standardRuleDeconjugate(form, rule)
        case "substitution":
            return substitutionDeconjugate(form, rule)
        default:
            return nil
        }
    }

    private static func standardRuleDeconjugate(_ form: JapaneseDeconjugationForm, _ rule: JapaneseDeconjugationRule) -> JapaneseDeconjugationForm? {
        if rule.detail.isEmpty, form.tags.isEmpty {
            return nil
        }

        guard form.text.hasSuffix(rule.conEnd) else {
            return nil
        }

        if let lastTag = form.tags.last, lastTag != rule.conTag {
            return nil
        }

        let prefix = form.text.dropLast(rule.conEnd.count)
        let newText = String(prefix) + rule.decEnd
        guard newText != form.originalText else {
            return nil
        }

        return makeForm(from: form, text: newText, conTag: rule.conTag, decTag: rule.decTag, detail: rule.detail)
    }

    private static func substitutionDeconjugate(_ form: JapaneseDeconjugationForm, _ rule: JapaneseDeconjugationRule) -> JapaneseDeconjugationForm? {
        guard form.process.isEmpty, !rule.conEnd.isEmpty, form.text.contains(rule.conEnd) else {
            return nil
        }

        let newText = form.text.replacingOccurrences(of: rule.conEnd, with: rule.decEnd)
        var seenText = form.seenText
        if seenText.isEmpty {
            seenText.insert(form.text)
        }
        seenText.insert(newText)

        return JapaneseDeconjugationForm(
            text: newText,
            originalText: form.originalText,
            tags: form.tags,
            seenText: seenText,
            process: appendingNonEmpty(rule.detail, to: form.process)
        )
    }

    private static func makeForm(from form: JapaneseDeconjugationForm, text newText: String, conTag: String?, decTag: String?, detail: String) -> JapaneseDeconjugationForm {
        var tags = form.tags
        if form.tags.isEmpty, let conTag, !conTag.isEmpty {
            tags.append(conTag)
        }
        if let decTag, !decTag.isEmpty {
            tags.append(decTag)
        }

        var seenText = form.seenText
        if seenText.isEmpty {
            seenText.insert(form.text)
        }
        seenText.insert(newText)

        return JapaneseDeconjugationForm(
            text: newText,
            originalText: form.originalText,
            tags: tags,
            seenText: seenText,
            process: appendingNonEmpty(detail, to: form.process)
        )
    }

    private static func shouldSkip(_ form: JapaneseDeconjugationForm) -> Bool {
        form.text.isEmpty ||
            form.text.count > form.originalText.count + 10 ||
            form.tags.count > form.originalText.count + 6
    }

    private static func contextRuleMatches(_ form: JapaneseDeconjugationForm, _ rule: JapaneseDeconjugationRule) -> Bool {
        switch rule.contextRule {
        case "v1inftrap":
            return form.tags != ["stem-ren"]
        case "saspecial":
            guard form.text.hasSuffix(rule.conEnd) else { return false }
            let prefixLength = form.text.count - rule.conEnd.count
            if prefixLength <= 0 { return true }
            let index = form.text.index(form.text.startIndex, offsetBy: prefixLength - 1)
            return form.text[index] != "さ"
        case "temirurule":
            guard form.text.hasSuffix(rule.conEnd) else { return false }
            let prefix = form.text.dropLast(rule.conEnd.count)
            return prefix.hasSuffix("て") || prefix.hasSuffix("で")
        case nil:
            return true
        default:
            return false
        }
    }

    private static func appendingNonEmpty(_ value: String, to values: [String]) -> [String] {
        guard !value.isEmpty else { return values }
        return values + [value]
    }
}
