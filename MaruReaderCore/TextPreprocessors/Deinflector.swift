// Deinflector.swift
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

// Portions of this file were derived from japanese-transforms.js.
// Copyright (C) 2024-2025  Yomitan Authors
// Used under the terms of the GNU General Public License v3.0

import Foundation

enum Condition: String, CaseIterable, Hashable {
    case v
    case v1
    case v1d
    case v1p
    case v5
    case v5d
    case v5s
    case v5ss
    case v5sp
    case vk
    case vs
    case vz
    case adj_i = "adj-i"
    case masu = "-ます"
    case masen = "-ません"
    case te = "-て"
    case ba = "-ば"
    case ku = "-く"
    case ta = "-た"
    case n = "-ん"
    case nasai = "-なさい"
    case ya = "-ゃ"

    /// Metadata (localized display name for UI)
    func displayName(for language: DeinflectionLanguage) -> String {
        let key = language.resolved.jsonKey
        switch key {
        case "ja":
            return jaDisplayName
        case "zh-Hant":
            return zhHantDisplayName
        case "zh-Hans":
            return zhHansDisplayName
        default:
            return enDisplayName
        }
    }

    private var enDisplayName: String {
        switch self {
        case .v: "Verb"
        case .v1: "Ichidan verb"
        case .v1d: "Ichidan verb, dictionary form"
        case .v1p: "Ichidan verb, progressive or perfect form"
        case .v5: "Godan verb"
        case .v5d: "Godan verb, dictionary form"
        case .v5s: "Godan verb, short causative form"
        case .v5ss: "Godan verb, short causative form having さす ending (cannot conjugate with passive form)"
        case .v5sp: "Godan verb, short causative form not having さす ending (can conjugate with passive form)"
        case .vk: "Kuru verb"
        case .vs: "Suru verb"
        case .vz: "Zuru verb"
        case .adj_i: "Adjective with i ending"
        case .masu: "Polite -ます ending"
        case .masen: "Polite negative -ません ending"
        case .te: "Intermediate -て endings for progressive or perfect tense"
        case .ba: "Intermediate -ば endings for conditional contraction"
        case .ku: "Intermediate -く endings for adverbs"
        case .ta: "-た form ending"
        case .n: "-ん negative ending"
        case .nasai: "Intermediate -なさい ending (polite imperative)"
        case .ya: "Intermediate -や ending (conditional contraction)"
        }
    }

    private var jaDisplayName: String {
        switch self {
        case .v: "動詞"
        case .v1: "一段動詞"
        case .v1d: "一段動詞・辞書形"
        case .v1p: "一段動詞・進行形または完了形"
        case .v5: "五段動詞"
        case .v5d: "五段動詞・辞書形"
        case .v5s: "五段動詞・使役短縮形"
        case .v5ss: "五段動詞・さす型使役短縮形（受身不可）"
        case .v5sp: "五段動詞・非さす型使役短縮形（受身可）"
        case .vk: "カ行変格動詞"
        case .vs: "サ行変格動詞"
        case .vz: "ザ行変格動詞"
        case .adj_i: "い形容詞"
        case .masu: "丁寧語 -ます"
        case .masen: "丁寧語否定 -ません"
        case .te: "中間 -て（進行形・完了形）"
        case .ba: "中間 -ば（条件縮約）"
        case .ku: "中間 -く（副詞化）"
        case .ta: "-た形"
        case .n: "-ん（否定）"
        case .nasai: "中間 -なさい（丁寧命令）"
        case .ya: "中間 -や（条件縮約）"
        }
    }

    private var zhHantDisplayName: String {
        switch self {
        case .v: "動詞"
        case .v1: "一段動詞"
        case .v1d: "一段動詞・辭書形"
        case .v1p: "一段動詞・進行或完成形"
        case .v5: "五段動詞"
        case .v5d: "五段動詞・辭書形"
        case .v5s: "五段動詞・使役縮約形"
        case .v5ss: "五段動詞・さす型使役縮約形（不可接受身）"
        case .v5sp: "五段動詞・非さす型使役縮約形（可接受身）"
        case .vk: "カ行變格動詞"
        case .vs: "サ行變格動詞"
        case .vz: "ザ行變格動詞"
        case .adj_i: "い形容詞"
        case .masu: "禮貌語 -ます"
        case .masen: "禮貌語否定 -ません"
        case .te: "中間 -て（進行・完成）"
        case .ba: "中間 -ば（條件縮約）"
        case .ku: "中間 -く（副詞化）"
        case .ta: "-た形"
        case .n: "-ん（否定）"
        case .nasai: "中間 -なさい（禮貌命令）"
        case .ya: "中間 -や（條件縮約）"
        }
    }

    private var zhHansDisplayName: String {
        switch self {
        case .v: "动词"
        case .v1: "一段动词"
        case .v1d: "一段动词・辞书形"
        case .v1p: "一段动词・进行或完成形"
        case .v5: "五段动词"
        case .v5d: "五段动词・辞书形"
        case .v5s: "五段动词・使役缩约形"
        case .v5ss: "五段动词・さす型使役缩约形（不可接受身）"
        case .v5sp: "五段动词・非さす型使役缩约形（可接受身）"
        case .vk: "カ行变格动词"
        case .vs: "サ行变格动词"
        case .vz: "ザ行变格动词"
        case .adj_i: "い形容词"
        case .masu: "礼貌语 -ます"
        case .masen: "礼貌语否定 -ません"
        case .te: "中间 -て（进行・完成）"
        case .ba: "中间 -ば（条件缩约）"
        case .ku: "中间 -く（副词化）"
        case .ta: "-た形"
        case .n: "-ん（否定）"
        case .nasai: "中间 -なさい（礼貌命令）"
        case .ya: "中间 -や（条件缩约）"
        }
    }
}

/// Struct for individual rules (suffix-only for Japanese)
struct SuffixRule {
    let inflectedSuffix: String // e.g., "ければ"
    let deinflectedSuffix: String // e.g., "い"
    let conditionsIn: [Condition] // Input conditions to apply this rule
    let conditionsOut: [Condition] // Output conditions after application

    /// Matching function
    func matches(_ text: String) -> Bool {
        text.hasSuffix(inflectedSuffix)
    }

    /// Deinflect function
    func deinflect(_ text: String) -> String {
        String(text.dropLast(inflectedSuffix.count)) + deinflectedSuffix
    }
}

/// Struct for transforms (groups rules with metadata; rule names are transform keys)
struct Transform {
    let name: String // e.g., "-ば" (used as "reason" in candidates)
    let localization: LocalizedDeinflectionContent
    let rules: [SuffixRule] // Array of suffixInflection ports
}

enum JapaneseDeinflector {
    /// Conditions metadata (port 'conditions' object)
    static let conditionDetails: [Condition: (name: String, isDictionaryForm: Bool, subConditions: [Condition])] = [
        .v: ("Verb", false, [.v1, .v5, .vk, .vs, .vz]),
        .v1: ("Ichidan verb", true, [.v1d, .v1p]),
        .v1d: ("Ichidan verb, dictionary form", false, []),
        .v1p: ("Ichidan verb, progressive or perfect form", false, []),
        .v5: ("Godan verb", true, [.v5d, .v5s]),
        .v5d: ("Godan verb, dictionary form", false, []),
        .v5s: ("Godan verb, short causative form", false, [.v5ss, .v5sp]),
        .v5ss: ("Godan verb, short causative form having さす ending (cannot conjugate with passive form)", false, []),
        .v5sp: ("Godan verb, short causative form not having さす ending (can conjugate with passive form)", false, []),
        .vk: ("Kuru verb", true, []),
        .vs: ("Suru verb", true, []),
        .vz: ("Zuru verb", true, []),
        .adj_i: ("Adjective with i ending", true, []),
        .masu: ("Polite -ます ending", false, []),
        .masen: ("Polite negative -ません ending", false, []),
        .te: ("Intermediate -て endings for progressive or perfect tense", false, []),
        .ba: ("Intermediate -ば endings for conditional contraction", false, []),
        .ku: ("Intermediate -く endings for adverbs", false, []),
        .ta: ("-た form ending", false, []),
        .n: ("-ん negative ending", false, []),
        .nasai: ("Intermediate -なさい ending (polite imperative)", false, []),
        .ya: ("Intermediate -や ending (conditional contraction)", false, []),
    ]

    /// Helper function to check if current conditions satisfy required conditions considering subcondition hierarchy
    private static func conditionsMatch(current: Set<Condition>, required: Set<Condition>) -> Bool {
        // If no requirements, any current conditions are fine
        if required.isEmpty { return true }

        // If no current conditions, can match any pattern
        if current.isEmpty { return true }

        // Check if any required condition is satisfied by current conditions or their ancestor conditions
        return required.contains { requiredCondition in
            // Direct match
            current.contains(requiredCondition) ||
                // Or current condition is an ancestor of required condition
                current.contains { currentCondition in
                    isAncestorCondition(ancestor: currentCondition, descendant: requiredCondition)
                }
        }
    }

    /// Helper function to check if ancestor condition contains descendant condition in its subcondition hierarchy
    private static func isAncestorCondition(ancestor: Condition, descendant: Condition) -> Bool {
        guard let subConditions = JapaneseDeinflector.conditionDetails[ancestor]?.subConditions else {
            return false
        }

        // Direct child
        if subConditions.contains(descendant) {
            return true
        }

        // Recursive check for deeper levels
        return subConditions.contains { subCondition in
            isAncestorCondition(ancestor: subCondition, descendant: descendant)
        }
    }

    /// Main function: Generate deinflected candidates with rule traces
    static func deinflect(_ text: String, maxDepth: Int = 10) -> [DeinflectionCandidate] {
        var candidates: [DeinflectionCandidate] = []
        var seen = Set<String>() // Avoid dups by (deinflected text, conditions) pairs

        // Queue for BFS (iterative to avoid stack overflow; tracks path)
        var queue: [(currentText: String, appliedRules: [String], currentConditions: Set<Condition>, depth: Int)] = [
            (text, [], [], 0), // Start with original, no rules, empty conditions
        ]

        while !queue.isEmpty {
            let item = queue.removeFirst()
            if item.depth > maxDepth { continue }

            let deinflected = item.currentText
            let stateKey = "\(deinflected)|\(item.currentConditions.sorted { $0.rawValue < $1.rawValue }.map(\.rawValue).joined(separator: ","))"
            if seen.contains(stateKey) { continue }
            seen.insert(stateKey)

            // Add as candidate:
            // - Always add the original input (depth 0) since it might be a dictionary form
            // - Always add forms reached through transformations (depth > 0) as they are potential dictionary forms
            candidates.append(DeinflectionCandidate(base: deinflected, transforms: item.appliedRules, conditions: item.currentConditions.map(\.rawValue)))

            // Apply matching transforms
            for transform in JapaneseDeinflector.transforms.values {
                for rule in transform.rules {
                    // Check if current conditions satisfy the rule's input requirements considering subcondition hierarchy
                    let currentConditionsSet = Set(item.currentConditions)
                    let requiredConditionsSet = Set(rule.conditionsIn)

                    if !conditionsMatch(current: currentConditionsSet, required: requiredConditionsSet) {
                        continue
                    }

                    if !rule.matches(deinflected) { continue }

                    let newText = rule.deinflect(deinflected)
                    let newRules = item.appliedRules + [transform.name] // Track rule name for UI

                    // Output conditions replace current conditions (they represent what this form can be)
                    let newConditions = Set(rule.conditionsOut)
                    queue.append((newText, newRules, newConditions, item.depth + 1))
                }
            }
        }

        // Sort by relevance: dictionary forms first then by transform count
        candidates.sort { candidate1, candidate2 in
            let candidate1HasDictionaryForm = candidate1.conditions.contains { conditionStr in
                guard let condition = Condition(rawValue: conditionStr) else { return false }
                return JapaneseDeinflector.conditionDetails[condition]?.isDictionaryForm == true
            }

            let candidate2HasDictionaryForm = candidate2.conditions.contains { conditionStr in
                guard let condition = Condition(rawValue: conditionStr) else { return false }
                return JapaneseDeinflector.conditionDetails[condition]?.isDictionaryForm == true
            }

            if candidate1HasDictionaryForm, !candidate2HasDictionaryForm {
                return true // Dictionary forms first
            } else if !candidate1HasDictionaryForm, candidate2HasDictionaryForm {
                return false
            } else {
                return candidate1.transforms.count < candidate2.transforms.count
            }
        }

        return candidates
    }

    /// Generate deinflected LookupCandidates, preserving original metadata and adding deinflection rules
    static func deinflect(_ candidate: LookupCandidate, maxDepth: Int = 10) -> [LookupCandidate] {
        let deinflectionCandidates = JapaneseDeinflector.deinflect(candidate.text, maxDepth: maxDepth)

        return deinflectionCandidates.map { deinflectionCandidate in
            // Add deinflection rules
            let newDeinflectionInputRules = candidate.deinflectionInputRules + [deinflectionCandidate.transforms]

            // Create new LookupCandidate with preserved metadata
            return LookupCandidate(
                text: deinflectionCandidate.base,
                originalSubstring: candidate.originalSubstring,
                preprocessorRules: candidate.preprocessorRules,
                deinflectionInputRules: newDeinflectionInputRules,
                deinflectionOutputRulesPerChain: [deinflectionCandidate.conditions]
            )
        }
    }
}

/// Candidate struct
struct DeinflectionCandidate {
    let base: String
    let transforms: [String]
    let conditions: [String]
}
