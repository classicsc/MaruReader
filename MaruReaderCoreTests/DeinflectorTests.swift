// DeinflectorTests.swift
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

// Portions of this file were derived from japanese-transforms-test.js.
// Copyright (C) 2024-2025  Yomitan Authors
// Used under the terms of the GNU General Public License v3.0

@testable import MaruReaderCore
import Testing

struct DeinflectorTests {
    // MARK: - Helper Methods

    @MainActor private func assertDeinflection(
        source: String,
        expectedBase: String,
        expectedReasons: [String]
    ) {
        let candidates = JapaneseDeinflector.deinflect(source)

        // Find matching candidate
        let matchingCandidate = candidates.first { candidate in
            candidate.base == expectedBase && Set(candidate.transforms) == Set(expectedReasons)
        }

        #expect(
            matchingCandidate != nil,
            "Expected to find candidate with base '\(expectedBase)' and reasons \(expectedReasons) for source '\(source)', but got candidates: \(candidates)"
        )
    }

    @MainActor private func assertNoDeinflection(
        source: String
    ) {
        let candidates = JapaneseDeinflector.deinflect(source)
        #expect(
            candidates.isEmpty,
            "Expected no deinflection candidates for '\(source)', but got: \(candidates)"
        )
    }

    // MARK: - I-Adjective Tests

    @MainActor @Test func iAdjectiveBasicForms() {
        // Base form
        assertDeinflection(source: "愛しい", expectedBase: "愛しい", expectedReasons: [])

        // -そう form (appearance)
        assertDeinflection(source: "愛しそう", expectedBase: "愛しい", expectedReasons: ["-そう"])

        // -すぎる form (excessive)
        assertDeinflection(source: "愛しすぎる", expectedBase: "愛しい", expectedReasons: ["-すぎる"])
        assertDeinflection(source: "愛し過ぎる", expectedBase: "愛しい", expectedReasons: ["-過ぎる"])

        // Conditional forms
        assertDeinflection(source: "愛しかったら", expectedBase: "愛しい", expectedReasons: ["-たら"])
        assertDeinflection(source: "愛しかったり", expectedBase: "愛しい", expectedReasons: ["-たり"])

        // Te-form and ku-form
        assertDeinflection(source: "愛しくて", expectedBase: "愛しい", expectedReasons: ["-て"])
        assertDeinflection(source: "愛しく", expectedBase: "愛しい", expectedReasons: ["-く"])

        // Negative
        assertDeinflection(source: "愛しくない", expectedBase: "愛しい", expectedReasons: ["negative"])

        // Nominalization
        assertDeinflection(source: "愛しさ", expectedBase: "愛しい", expectedReasons: ["-さ"])

        // Past tense
        assertDeinflection(source: "愛しかった", expectedBase: "愛しい", expectedReasons: ["-た"])

        // Polite negative forms
        assertDeinflection(source: "愛しくありません", expectedBase: "愛しい", expectedReasons: ["-ます", "negative"])
        assertDeinflection(source: "愛しくありませんでした", expectedBase: "愛しい", expectedReasons: ["-ます", "negative", "-た"])
        assertDeinflection(source: "愛しくありませんかった", expectedBase: "愛しい", expectedReasons: ["-ます", "negative", "-た"])

        // Literary forms
        assertDeinflection(source: "愛しき", expectedBase: "愛しい", expectedReasons: ["-き"])
        assertDeinflection(source: "愛しげ", expectedBase: "愛しい", expectedReasons: ["-げ"])
        assertDeinflection(source: "愛し気", expectedBase: "愛しい", expectedReasons: ["-げ"])
        assertDeinflection(source: "愛しがる", expectedBase: "愛しい", expectedReasons: ["-がる"])
    }

    // MARK: - Ichidan Verb Tests

    @MainActor @Test func ichidanVerbBasicForms() {
        // Base form
        assertDeinflection(source: "食べる", expectedBase: "食べる", expectedReasons: [])

        // Polite forms
        assertDeinflection(source: "食べます", expectedBase: "食べる", expectedReasons: ["-ます"])

        // Past tense
        assertDeinflection(source: "食べた", expectedBase: "食べる", expectedReasons: ["-た"])
        assertDeinflection(source: "食べました", expectedBase: "食べる", expectedReasons: ["-ます", "-た"])

        // Te-form
        assertDeinflection(source: "食べて", expectedBase: "食べる", expectedReasons: ["-て"])

        // Potential/Passive
        assertDeinflection(source: "食べられる", expectedBase: "食べる", expectedReasons: ["potential or passive"])

        // Causative
        assertDeinflection(source: "食べさせる", expectedBase: "食べる", expectedReasons: ["causative"])
        assertDeinflection(source: "食べさす", expectedBase: "食べる", expectedReasons: ["short causative"])
        assertDeinflection(source: "食べさします", expectedBase: "食べる", expectedReasons: ["short causative", "-ます"])

        // Causative + Passive
        assertDeinflection(source: "食べさせられる", expectedBase: "食べる", expectedReasons: ["causative", "potential or passive"])

        // Imperative
        assertDeinflection(source: "食べろ", expectedBase: "食べる", expectedReasons: ["imperative"])

        // Negative forms
        assertDeinflection(source: "食べない", expectedBase: "食べる", expectedReasons: ["negative"])
        assertDeinflection(source: "食べません", expectedBase: "食べる", expectedReasons: ["-ます", "negative"])
        assertDeinflection(source: "食べなかった", expectedBase: "食べる", expectedReasons: ["negative", "-た"])
        assertDeinflection(source: "食べませんでした", expectedBase: "食べる", expectedReasons: ["-ます", "negative", "-た"])
        assertDeinflection(source: "食べなくて", expectedBase: "食べる", expectedReasons: ["negative", "-て"])

        // Negative potential/passive
        assertDeinflection(source: "食べられない", expectedBase: "食べる", expectedReasons: ["potential or passive", "negative"])

        // Negative causative
        assertDeinflection(source: "食べさせない", expectedBase: "食べる", expectedReasons: ["causative", "negative"])
        assertDeinflection(source: "食べささない", expectedBase: "食べる", expectedReasons: ["short causative", "negative"])

        // Polite te-form
        assertDeinflection(source: "食べまして", expectedBase: "食べる", expectedReasons: ["-ます", "-て"])
    }

    @MainActor @Test func ichidanVerbConditionalAndSpecialForms() {
        // Conditional
        assertDeinflection(source: "食べれば", expectedBase: "食べる", expectedReasons: ["-ば"])
        assertDeinflection(source: "食べりゃ", expectedBase: "食べる", expectedReasons: ["-ば", "-ゃ"])

        // Contraction forms
        assertDeinflection(source: "食べちゃ", expectedBase: "食べる", expectedReasons: ["-ちゃ"])
        assertDeinflection(source: "食べちゃう", expectedBase: "食べる", expectedReasons: ["-ちゃう"])
        assertDeinflection(source: "食べちまう", expectedBase: "食べる", expectedReasons: ["-ちまう"])

        // Polite imperative
        assertDeinflection(source: "食べなさい", expectedBase: "食べる", expectedReasons: ["-なさい"])

        // Appearance/hearsay
        assertDeinflection(source: "食べそう", expectedBase: "食べる", expectedReasons: ["-そう"])

        // Excessive
        assertDeinflection(source: "食べすぎる", expectedBase: "食べる", expectedReasons: ["-すぎる"])
        assertDeinflection(source: "食べ過ぎる", expectedBase: "食べる", expectedReasons: ["-過ぎる"])

        // Desire
        assertDeinflection(source: "食べたい", expectedBase: "食べる", expectedReasons: ["-たい"])
        assertDeinflection(source: "食べたがる", expectedBase: "食べる", expectedReasons: ["-たい", "-がる"])

        // Conditional past
        assertDeinflection(source: "食べたら", expectedBase: "食べる", expectedReasons: ["-たら"])
        assertDeinflection(source: "食べたり", expectedBase: "食べる", expectedReasons: ["-たり"])

        // Literary negative forms
        assertDeinflection(source: "食べず", expectedBase: "食べる", expectedReasons: ["-ず"])
        assertDeinflection(source: "食べぬ", expectedBase: "食べる", expectedReasons: ["-ぬ"])
        assertDeinflection(source: "食べん", expectedBase: "食べる", expectedReasons: ["-ん"])
        assertDeinflection(source: "食べんかった", expectedBase: "食べる", expectedReasons: ["-ん", "-た"])
        assertDeinflection(source: "食べんばかり", expectedBase: "食べる", expectedReasons: ["-んばかり"])
        assertDeinflection(source: "食べんとする", expectedBase: "食べる", expectedReasons: ["-んとする"])
        assertDeinflection(source: "食べざる", expectedBase: "食べる", expectedReasons: ["-ざる"])
        assertDeinflection(source: "食べねば", expectedBase: "食べる", expectedReasons: ["-ねば"])
        assertDeinflection(source: "食べにゃ", expectedBase: "食べる", expectedReasons: ["-ねば", "-ゃ"])

        // Continuative (stem form)
        assertDeinflection(source: "食べ", expectedBase: "食べる", expectedReasons: ["continuative"])

        // Volitional
        assertDeinflection(source: "食べましょう", expectedBase: "食べる", expectedReasons: ["-ます", "volitional"])
        assertDeinflection(source: "食べましょっか", expectedBase: "食べる", expectedReasons: ["-ます", "volitional slang"])
        assertDeinflection(source: "食べよう", expectedBase: "食べる", expectedReasons: ["volitional"])
        assertDeinflection(source: "食べよっか", expectedBase: "食べる", expectedReasons: ["volitional slang"])

        // Negative volitional
        assertDeinflection(source: "食べるまい", expectedBase: "食べる", expectedReasons: ["-まい"])
        assertDeinflection(source: "食べまい", expectedBase: "食べる", expectedReasons: ["-まい"])
    }

    @MainActor @Test func ichidanVerbAuxiliaryForms() {
        // -ておく forms (preparatory)
        assertDeinflection(source: "食べておく", expectedBase: "食べる", expectedReasons: ["-て", "-おく"])
        assertDeinflection(source: "食べとく", expectedBase: "食べる", expectedReasons: ["-て", "-おく"])
        assertDeinflection(source: "食べないでおく", expectedBase: "食べる", expectedReasons: ["negative", "-おく"])
        assertDeinflection(source: "食べないどく", expectedBase: "食べる", expectedReasons: ["negative", "-おく"])

        // -ている forms (progressive)
        assertDeinflection(source: "食べている", expectedBase: "食べる", expectedReasons: ["-て", "-いる"])
        assertDeinflection(source: "食べておる", expectedBase: "食べる", expectedReasons: ["-て", "-いる"])
        assertDeinflection(source: "食べてる", expectedBase: "食べる", expectedReasons: ["-て", "-いる"])
        assertDeinflection(source: "食べとる", expectedBase: "食べる", expectedReasons: ["-て", "-いる"])

        // -てしまう form (completion/regret)
        assertDeinflection(source: "食べてしまう", expectedBase: "食べる", expectedReasons: ["-て", "-しまう"])
    }

    // MARK: - Godan -u Verb Tests

    @MainActor @Test func godanUVerbBasicForms() {
        // Base form
        assertDeinflection(source: "買う", expectedBase: "買う", expectedReasons: [])

        // Polite forms
        assertDeinflection(source: "買います", expectedBase: "買う", expectedReasons: ["-ます"])

        // Past tense (euphonic change)
        assertDeinflection(source: "買った", expectedBase: "買う", expectedReasons: ["-た"])
        assertDeinflection(source: "買いました", expectedBase: "買う", expectedReasons: ["-ます", "-た"])

        // Te-form (euphonic change)
        assertDeinflection(source: "買って", expectedBase: "買う", expectedReasons: ["-て"])

        // Potential
        assertDeinflection(source: "買える", expectedBase: "買う", expectedReasons: ["potential"])

        // Passive
        assertDeinflection(source: "買われる", expectedBase: "買う", expectedReasons: ["passive"])

        // Causative
        assertDeinflection(source: "買わせる", expectedBase: "買う", expectedReasons: ["causative"])
        assertDeinflection(source: "買わす", expectedBase: "買う", expectedReasons: ["short causative"])
        assertDeinflection(source: "買わします", expectedBase: "買う", expectedReasons: ["short causative", "-ます"])

        // Causative + Passive
        assertDeinflection(source: "買わせられる", expectedBase: "買う", expectedReasons: ["causative", "potential or passive"])

        // Imperative
        assertDeinflection(source: "買え", expectedBase: "買う", expectedReasons: ["imperative"])

        // Negative forms
        assertDeinflection(source: "買わない", expectedBase: "買う", expectedReasons: ["negative"])
        assertDeinflection(source: "買いません", expectedBase: "買う", expectedReasons: ["-ます", "negative"])
        assertDeinflection(source: "買わなかった", expectedBase: "買う", expectedReasons: ["negative", "-た"])
        assertDeinflection(source: "買いませんでした", expectedBase: "買う", expectedReasons: ["-ます", "negative", "-た"])
        assertDeinflection(source: "買わなくて", expectedBase: "買う", expectedReasons: ["negative", "-て"])

        // Volitional
        assertDeinflection(source: "買おう", expectedBase: "買う", expectedReasons: ["volitional"])
        assertDeinflection(source: "買おっか", expectedBase: "買う", expectedReasons: ["volitional slang"])

        // Short causative passive
        assertDeinflection(source: "買わされる", expectedBase: "買う", expectedReasons: ["short causative", "passive"])
    }

    @MainActor @Test func godanUVerbSpecialForms() {
        // Conditional
        assertDeinflection(source: "買えば", expectedBase: "買う", expectedReasons: ["-ば"])
        assertDeinflection(source: "買や", expectedBase: "買う", expectedReasons: ["-ば", "-ゃ"])

        // Contraction forms
        assertDeinflection(source: "買っちゃ", expectedBase: "買う", expectedReasons: ["-ちゃ"])
        assertDeinflection(source: "買っちゃう", expectedBase: "買う", expectedReasons: ["-ちゃう"])
        assertDeinflection(source: "買っちまう", expectedBase: "買う", expectedReasons: ["-ちまう"])

        // Other special forms
        assertDeinflection(source: "買いなさい", expectedBase: "買う", expectedReasons: ["-なさい"])
        assertDeinflection(source: "買いそう", expectedBase: "買う", expectedReasons: ["-そう"])
        assertDeinflection(source: "買いすぎる", expectedBase: "買う", expectedReasons: ["-すぎる"])
        assertDeinflection(source: "買い過ぎる", expectedBase: "買う", expectedReasons: ["-過ぎる"])
        assertDeinflection(source: "買いたい", expectedBase: "買う", expectedReasons: ["-たい"])
        assertDeinflection(source: "買いたがる", expectedBase: "買う", expectedReasons: ["-たい", "-がる"])

        // Literary negative forms
        assertDeinflection(source: "買わず", expectedBase: "買う", expectedReasons: ["-ず"])
        assertDeinflection(source: "買わぬ", expectedBase: "買う", expectedReasons: ["-ぬ"])
        assertDeinflection(source: "買わん", expectedBase: "買う", expectedReasons: ["-ん"])

        // Continuative
        assertDeinflection(source: "買い", expectedBase: "買う", expectedReasons: ["continuative"])

        // Auxiliary verb forms
        assertDeinflection(source: "買っておく", expectedBase: "買う", expectedReasons: ["-て", "-おく"])
        assertDeinflection(source: "買っとく", expectedBase: "買う", expectedReasons: ["-て", "-おく"])
        assertDeinflection(source: "買っている", expectedBase: "買う", expectedReasons: ["-て", "-いる"])
        assertDeinflection(source: "買ってる", expectedBase: "買う", expectedReasons: ["-て", "-いる"])
        assertDeinflection(source: "買ってしまう", expectedBase: "買う", expectedReasons: ["-て", "-しまう"])

        // Polite combinations
        assertDeinflection(source: "買いますまい", expectedBase: "買う", expectedReasons: ["-ます", "-まい"])
        assertDeinflection(source: "買いましたら", expectedBase: "買う", expectedReasons: ["-ます", "-たら"])
        assertDeinflection(source: "買いますれば", expectedBase: "買う", expectedReasons: ["-ます", "-ば"])
        assertDeinflection(source: "買いませんかった", expectedBase: "買う", expectedReasons: ["-ます", "negative", "-た"])
    }

    // MARK: - Godan -ku Verb Tests (Special euphonic changes)

    @MainActor @Test func godanKuVerbForms() {
        // Base form
        assertDeinflection(source: "行く", expectedBase: "行く", expectedReasons: [])

        // Special euphonic changes for -ku verbs
        assertDeinflection(source: "行った", expectedBase: "行く", expectedReasons: ["-た"])
        assertDeinflection(source: "行って", expectedBase: "行く", expectedReasons: ["-て"])

        // Regular forms
        assertDeinflection(source: "行きます", expectedBase: "行く", expectedReasons: ["-ます"])
        assertDeinflection(source: "行ける", expectedBase: "行く", expectedReasons: ["potential"])
        assertDeinflection(source: "行かない", expectedBase: "行く", expectedReasons: ["negative"])
        assertDeinflection(source: "行こう", expectedBase: "行く", expectedReasons: ["volitional"])
    }

    // MARK: - Godan -su Verb Tests

    @MainActor @Test func godanSuVerbForms() {
        // Base form
        assertDeinflection(source: "話す", expectedBase: "話す", expectedReasons: [])

        // Past and te-form
        assertDeinflection(source: "話した", expectedBase: "話す", expectedReasons: ["-た"])
        assertDeinflection(source: "話して", expectedBase: "話す", expectedReasons: ["-て"])

        // Other forms
        assertDeinflection(source: "話します", expectedBase: "話す", expectedReasons: ["-ます"])
        assertDeinflection(source: "話せる", expectedBase: "話す", expectedReasons: ["potential"])
        assertDeinflection(source: "話される", expectedBase: "話す", expectedReasons: ["passive"])
        assertDeinflection(source: "話さない", expectedBase: "話す", expectedReasons: ["negative"])
        assertDeinflection(source: "話そう", expectedBase: "話す", expectedReasons: ["volitional"])
    }

    // MARK: - Godan -bu, -mu, -nu Verb Tests (n-euphonic change)

    @MainActor @Test func godanBuVerbForms() {
        // Base form
        assertDeinflection(source: "遊ぶ", expectedBase: "遊ぶ", expectedReasons: [])

        // Euphonic change to ん
        assertDeinflection(source: "遊んだ", expectedBase: "遊ぶ", expectedReasons: ["-た"])
        assertDeinflection(source: "遊んで", expectedBase: "遊ぶ", expectedReasons: ["-て"])

        // Other forms
        assertDeinflection(source: "遊びます", expectedBase: "遊ぶ", expectedReasons: ["-ます"])
        assertDeinflection(source: "遊べる", expectedBase: "遊ぶ", expectedReasons: ["potential"])
        assertDeinflection(source: "遊ばない", expectedBase: "遊ぶ", expectedReasons: ["negative"])
        assertDeinflection(source: "遊ぼう", expectedBase: "遊ぶ", expectedReasons: ["volitional"])
    }

    @MainActor @Test func godanMuVerbForms() {
        // Base form
        assertDeinflection(source: "読む", expectedBase: "読む", expectedReasons: [])

        // Euphonic change to ん
        assertDeinflection(source: "読んだ", expectedBase: "読む", expectedReasons: ["-た"])
        assertDeinflection(source: "読んで", expectedBase: "読む", expectedReasons: ["-て"])

        // Other forms
        assertDeinflection(source: "読みます", expectedBase: "読む", expectedReasons: ["-ます"])
        assertDeinflection(source: "読める", expectedBase: "読む", expectedReasons: ["potential"])
        assertDeinflection(source: "読まない", expectedBase: "読む", expectedReasons: ["negative"])
        assertDeinflection(source: "読もう", expectedBase: "読む", expectedReasons: ["volitional"])
    }

    @MainActor @Test func godanNuVerbForms() {
        // Base form
        assertDeinflection(source: "死ぬ", expectedBase: "死ぬ", expectedReasons: [])

        // Euphonic change to ん
        assertDeinflection(source: "死んだ", expectedBase: "死ぬ", expectedReasons: ["-た"])
        assertDeinflection(source: "死んで", expectedBase: "死ぬ", expectedReasons: ["-て"])

        // Other forms
        assertDeinflection(source: "死にます", expectedBase: "死ぬ", expectedReasons: ["-ます"])
        assertDeinflection(source: "死ねる", expectedBase: "死ぬ", expectedReasons: ["potential"])
        assertDeinflection(source: "死なない", expectedBase: "死ぬ", expectedReasons: ["negative"])
        assertDeinflection(source: "死のう", expectedBase: "死ぬ", expectedReasons: ["volitional"])
    }

    // MARK: - Godan -tsu, -gu Verb Tests

    @MainActor @Test func godanTsuVerbForms() {
        // Base form
        assertDeinflection(source: "立つ", expectedBase: "立つ", expectedReasons: [])

        // Euphonic change
        assertDeinflection(source: "立った", expectedBase: "立つ", expectedReasons: ["-た"])
        assertDeinflection(source: "立って", expectedBase: "立つ", expectedReasons: ["-て"])

        // Other forms
        assertDeinflection(source: "立ちます", expectedBase: "立つ", expectedReasons: ["-ます"])
        assertDeinflection(source: "立てる", expectedBase: "立つ", expectedReasons: ["potential"])
        assertDeinflection(source: "立たない", expectedBase: "立つ", expectedReasons: ["negative"])
        assertDeinflection(source: "立とう", expectedBase: "立つ", expectedReasons: ["volitional"])
    }

    @MainActor @Test func godanGuVerbForms() {
        // Base form
        assertDeinflection(source: "泳ぐ", expectedBase: "泳ぐ", expectedReasons: [])

        // Euphonic change
        assertDeinflection(source: "泳いだ", expectedBase: "泳ぐ", expectedReasons: ["-た"])
        assertDeinflection(source: "泳いで", expectedBase: "泳ぐ", expectedReasons: ["-て"])

        // Other forms
        assertDeinflection(source: "泳ぎます", expectedBase: "泳ぐ", expectedReasons: ["-ます"])
        assertDeinflection(source: "泳げる", expectedBase: "泳ぐ", expectedReasons: ["potential"])
        assertDeinflection(source: "泳がない", expectedBase: "泳ぐ", expectedReasons: ["negative"])
        assertDeinflection(source: "泳ごう", expectedBase: "泳ぐ", expectedReasons: ["volitional"])
    }

    // MARK: - Irregular Verb Tests (suru)

    @MainActor @Test func suruVerbForms() {
        // Base form
        assertDeinflection(source: "する", expectedBase: "する", expectedReasons: [])

        // Past tense
        assertDeinflection(source: "した", expectedBase: "する", expectedReasons: ["-た"])

        // Te-form
        assertDeinflection(source: "して", expectedBase: "する", expectedReasons: ["-て"])

        // Special potential form
        assertDeinflection(source: "できる", expectedBase: "する", expectedReasons: ["potential"])

        // Passive
        assertDeinflection(source: "される", expectedBase: "する", expectedReasons: ["passive"])

        // Causative
        assertDeinflection(source: "させる", expectedBase: "する", expectedReasons: ["causative"])

        // Negative
        assertDeinflection(source: "しない", expectedBase: "する", expectedReasons: ["negative"])

        // Polite
        assertDeinflection(source: "します", expectedBase: "する", expectedReasons: ["-ます"])

        // Volitional
        assertDeinflection(source: "しよう", expectedBase: "する", expectedReasons: ["volitional"])

        // Imperative
        assertDeinflection(source: "しろ", expectedBase: "する", expectedReasons: ["imperative"])
        assertDeinflection(source: "せよ", expectedBase: "する", expectedReasons: ["imperative"])
    }

    // MARK: - Irregular Verb Tests (kuru)

    @MainActor @Test func kuruVerbForms() {
        // Base form
        assertDeinflection(source: "来る", expectedBase: "来る", expectedReasons: [])

        // Past tense
        assertDeinflection(source: "来た", expectedBase: "来る", expectedReasons: ["-た"])

        // Te-form
        assertDeinflection(source: "来て", expectedBase: "来る", expectedReasons: ["-て"])

        // Potential/Passive
        assertDeinflection(source: "来られる", expectedBase: "来る", expectedReasons: ["potential or passive"])

        // Causative
        assertDeinflection(source: "来させる", expectedBase: "来る", expectedReasons: ["causative"])

        // Negative
        assertDeinflection(source: "来ない", expectedBase: "来る", expectedReasons: ["negative"])

        // Polite
        assertDeinflection(source: "来ます", expectedBase: "来る", expectedReasons: ["-ます"])

        // Volitional
        assertDeinflection(source: "来よう", expectedBase: "来る", expectedReasons: ["volitional"])

        // Imperative
        assertDeinflection(source: "来い", expectedBase: "来る", expectedReasons: ["imperative"])
    }

    // MARK: - Complex Transformation Chain Tests

    @MainActor @Test func complexTransformationChains() {
        // Multiple transformations
        assertDeinflection(
            source: "食べさせられたくなかった",
            expectedBase: "食べる",
            expectedReasons: ["causative", "potential or passive", "-たい", "negative", "-た"]
        )

        assertDeinflection(
            source: "買わされていました",
            expectedBase: "買う",
            expectedReasons: ["short causative", "passive", "-て", "-いる", "-ます", "-た"]
        )

        assertDeinflection(
            source: "話させられてしまった",
            expectedBase: "話す",
            expectedReasons: ["causative", "potential or passive", "-て", "-しまう", "-た"]
        )
    }

    // MARK: - Max Depth Tests

    @MainActor @Test func maxDepthLimiting() {
        // Test with limited max depth
        let shallowCandidates = JapaneseDeinflector.deinflect("食べさせられたくなかった", maxDepth: 2)
        let deepCandidates = JapaneseDeinflector.deinflect("食べさせられたくなかった", maxDepth: 10)

        // Shallow should have fewer candidates than deep
        #expect(shallowCandidates.count <= deepCandidates.count)
    }

    // MARK: - Edge Cases and Invalid Forms

    @MainActor @Test func invalidForms() {
        // Invalid conjugations (these should not produce valid results)
        let invalidResults = JapaneseDeinflector.deinflect("食べるない") // Invalid double verb ending
        #expect(invalidResults.isEmpty || !invalidResults.contains { $0.base == "食べる" && $0.transforms.contains("negative") })
    }

    // MARK: - Dictionary Form Sorting Tests

    @MainActor @Test func dictionaryFormsSortedFirst() {
        // Test that dictionary forms (those with isDictionaryForm=true conditions) are sorted first
        let candidates = JapaneseDeinflector.deinflect("食べます") // Should produce both 食べる and intermediate forms

        // Find candidates with dictionary forms vs non-dictionary forms
        var dictionaryFormCandidates: [DeinflectionCandidate] = []
        var nonDictionaryFormCandidates: [DeinflectionCandidate] = []

        for candidate in candidates {
            let hasDictionaryForm = candidate.conditions.contains { conditionStr in
                guard let condition = Condition(rawValue: conditionStr) else { return false }
                return JapaneseDeinflector.conditionDetails[condition]?.isDictionaryForm == true
            }

            if hasDictionaryForm {
                dictionaryFormCandidates.append(candidate)
            } else {
                nonDictionaryFormCandidates.append(candidate)
            }
        }

        // Verify we have both types
        #expect(!dictionaryFormCandidates.isEmpty, "Should have dictionary form candidates")
        #expect(!nonDictionaryFormCandidates.isEmpty, "Should have non-dictionary form candidates")

        // Find the indices of the first dictionary form and first non-dictionary form
        var firstDictionaryIndex: Int?
        var firstNonDictionaryIndex: Int?

        for (index, candidate) in candidates.enumerated() {
            let hasDictionaryForm = candidate.conditions.contains { conditionStr in
                guard let condition = Condition(rawValue: conditionStr) else { return false }
                return JapaneseDeinflector.conditionDetails[condition]?.isDictionaryForm == true
            }

            if hasDictionaryForm, firstDictionaryIndex == nil {
                firstDictionaryIndex = index
            } else if !hasDictionaryForm, firstNonDictionaryIndex == nil {
                firstNonDictionaryIndex = index
            }

            if firstDictionaryIndex != nil, firstNonDictionaryIndex != nil {
                break
            }
        }

        // Dictionary forms should come before non-dictionary forms
        if let dictIndex = firstDictionaryIndex, let nonDictIndex = firstNonDictionaryIndex {
            #expect(dictIndex < nonDictIndex, "Dictionary forms should be sorted before non-dictionary forms")
        }
    }

    // MARK: - Real-world Examples

    @MainActor @Test func realWorldExamples() {
        // Common expressions found in Japanese text
        assertDeinflection(source: "やっている", expectedBase: "やる", expectedReasons: ["-て", "-いる"])
        assertDeinflection(source: "言っている", expectedBase: "言う", expectedReasons: ["-て", "-いる"])
        assertDeinflection(source: "思っている", expectedBase: "思う", expectedReasons: ["-て", "-いる"])
        assertDeinflection(source: "知っている", expectedBase: "知る", expectedReasons: ["-て", "-いる"])
        assertDeinflection(source: "持っている", expectedBase: "持つ", expectedReasons: ["-て", "-いる"])

        // Polite forms commonly found
        assertDeinflection(source: "います", expectedBase: "いる", expectedReasons: ["-ます"])
        assertDeinflection(source: "あります", expectedBase: "ある", expectedReasons: ["-ます"])
        assertDeinflection(source: "できます", expectedBase: "する", expectedReasons: ["potential", "-ます"])

        // Past tense forms
        assertDeinflection(source: "いました", expectedBase: "いる", expectedReasons: ["-ます", "-た"])
        assertDeinflection(source: "ありました", expectedBase: "ある", expectedReasons: ["-ます", "-た"])
        assertDeinflection(source: "できました", expectedBase: "する", expectedReasons: ["potential", "-ます", "-た"])

        // Negative forms
        assertDeinflection(source: "いません", expectedBase: "いる", expectedReasons: ["-ます", "negative"])
        assertDeinflection(source: "ありません", expectedBase: "ある", expectedReasons: ["-ます", "negative"])
        assertDeinflection(source: "できません", expectedBase: "する", expectedReasons: ["potential", "-ます", "negative"])
    }
}
