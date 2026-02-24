// DeinflectionTransforms.swift
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

extension JapaneseDeinflector {
    static let localizations: [String: LocalizedDeinflectionContent] = loadDeinflectionLocalizations()

    static let transforms: [String: Transform] = {
        let loc = localizations
        var dict: [String: Transform] = [:]

        dict["-ば"] = Transform(
            name: "-ば",
            localization: loc["-ば"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "ければ", deinflectedSuffix: "い", conditionsIn: [.ba], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "えば", deinflectedSuffix: "う", conditionsIn: [.ba], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "けば", deinflectedSuffix: "く", conditionsIn: [.ba], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "げば", deinflectedSuffix: "ぐ", conditionsIn: [.ba], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "せば", deinflectedSuffix: "す", conditionsIn: [.ba], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "てば", deinflectedSuffix: "つ", conditionsIn: [.ba], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ねば", deinflectedSuffix: "ぬ", conditionsIn: [.ba], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "べば", deinflectedSuffix: "ぶ", conditionsIn: [.ba], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "めば", deinflectedSuffix: "む", conditionsIn: [.ba], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "れば", deinflectedSuffix: "る", conditionsIn: [.ba], conditionsOut: [.v1, .v5, .vk, .vs, .vz]),
                SuffixRule(inflectedSuffix: "れば", deinflectedSuffix: "", conditionsIn: [.ba], conditionsOut: [.masu]),
            ]
        )

        dict["-ゃ"] = Transform(
            name: "-ゃ",
            localization: loc["-ゃ"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "けりゃ", deinflectedSuffix: "ければ", conditionsIn: [.ya], conditionsOut: [.ba]),
                SuffixRule(inflectedSuffix: "きゃ", deinflectedSuffix: "ければ", conditionsIn: [.ya], conditionsOut: [.ba]),
                SuffixRule(inflectedSuffix: "や", deinflectedSuffix: "えば", conditionsIn: [.ya], conditionsOut: [.ba]),
                SuffixRule(inflectedSuffix: "きゃ", deinflectedSuffix: "けば", conditionsIn: [.ya], conditionsOut: [.ba]),
                SuffixRule(inflectedSuffix: "ぎゃ", deinflectedSuffix: "げば", conditionsIn: [.ya], conditionsOut: [.ba]),
                SuffixRule(inflectedSuffix: "しゃ", deinflectedSuffix: "せば", conditionsIn: [.ya], conditionsOut: [.ba]),
                SuffixRule(inflectedSuffix: "ちゃ", deinflectedSuffix: "てば", conditionsIn: [.ya], conditionsOut: [.ba]),
                SuffixRule(inflectedSuffix: "にゃ", deinflectedSuffix: "ねば", conditionsIn: [.ya], conditionsOut: [.ba]),
                SuffixRule(inflectedSuffix: "びゃ", deinflectedSuffix: "べば", conditionsIn: [.ya], conditionsOut: [.ba]),
                SuffixRule(inflectedSuffix: "みゃ", deinflectedSuffix: "めば", conditionsIn: [.ya], conditionsOut: [.ba]),
                SuffixRule(inflectedSuffix: "りゃ", deinflectedSuffix: "れば", conditionsIn: [.ya], conditionsOut: [.ba]),
            ]
        )

        dict["-ちゃ"] = Transform(
            name: "-ちゃ",
            localization: loc["-ちゃ"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "ちゃ", deinflectedSuffix: "る", conditionsIn: [.v5], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "いじゃ", deinflectedSuffix: "ぐ", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "いちゃ", deinflectedSuffix: "く", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "しちゃ", deinflectedSuffix: "す", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "っちゃ", deinflectedSuffix: "う", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "っちゃ", deinflectedSuffix: "く", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "っちゃ", deinflectedSuffix: "つ", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "っちゃ", deinflectedSuffix: "る", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "んじゃ", deinflectedSuffix: "ぬ", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "んじゃ", deinflectedSuffix: "ぶ", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "んじゃ", deinflectedSuffix: "む", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "じちゃ", deinflectedSuffix: "ずる", conditionsIn: [.v5], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "しちゃ", deinflectedSuffix: "する", conditionsIn: [.v5], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為ちゃ", deinflectedSuffix: "為る", conditionsIn: [.v5], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "きちゃ", deinflectedSuffix: "くる", conditionsIn: [.v5], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来ちゃ", deinflectedSuffix: "来る", conditionsIn: [.v5], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來ちゃ", deinflectedSuffix: "來る", conditionsIn: [.v5], conditionsOut: [.vk]),
            ]
        )

        dict["-ちゃう"] = Transform(
            name: "-ちゃう",
            localization: loc["-ちゃう"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "ちゃう", deinflectedSuffix: "る", conditionsIn: [.v5], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "いじゃう", deinflectedSuffix: "ぐ", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "いちゃう", deinflectedSuffix: "く", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "しちゃう", deinflectedSuffix: "す", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "っちゃう", deinflectedSuffix: "う", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "っちゃう", deinflectedSuffix: "く", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "っちゃう", deinflectedSuffix: "つ", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "っちゃう", deinflectedSuffix: "る", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "んじゃう", deinflectedSuffix: "ぬ", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "んじゃう", deinflectedSuffix: "ぶ", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "んじゃう", deinflectedSuffix: "む", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "じちゃう", deinflectedSuffix: "ずる", conditionsIn: [.v5], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "しちゃう", deinflectedSuffix: "する", conditionsIn: [.v5], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為ちゃう", deinflectedSuffix: "為る", conditionsIn: [.v5], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "きちゃう", deinflectedSuffix: "くる", conditionsIn: [.v5], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来ちゃう", deinflectedSuffix: "来る", conditionsIn: [.v5], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來ちゃう", deinflectedSuffix: "來る", conditionsIn: [.v5], conditionsOut: [.vk]),
            ]
        )

        dict["-ちまう"] = Transform(
            name: "-ちまう",
            localization: loc["-ちまう"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "ちまう", deinflectedSuffix: "る", conditionsIn: [.v5], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "いじまう", deinflectedSuffix: "ぐ", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "いちまう", deinflectedSuffix: "く", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "しちまう", deinflectedSuffix: "す", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "っちまう", deinflectedSuffix: "う", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "っちまう", deinflectedSuffix: "く", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "っちまう", deinflectedSuffix: "つ", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "っちまう", deinflectedSuffix: "る", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "んじまう", deinflectedSuffix: "ぬ", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "んじまう", deinflectedSuffix: "ぶ", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "んじまう", deinflectedSuffix: "む", conditionsIn: [.v5], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "じちまう", deinflectedSuffix: "ずる", conditionsIn: [.v5], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "しちまう", deinflectedSuffix: "する", conditionsIn: [.v5], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為ちまう", deinflectedSuffix: "為る", conditionsIn: [.v5], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "きちまう", deinflectedSuffix: "くる", conditionsIn: [.v5], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来ちまう", deinflectedSuffix: "来る", conditionsIn: [.v5], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來ちまう", deinflectedSuffix: "來る", conditionsIn: [.v5], conditionsOut: [.vk]),
            ]
        )

        dict["-しまう"] = Transform(
            name: "-しまう",
            localization: loc["-しまう"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "てしまう", deinflectedSuffix: "て", conditionsIn: [.v5], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "でしまう", deinflectedSuffix: "で", conditionsIn: [.v5], conditionsOut: [.te]),
            ]
        )

        dict["-なさい"] = Transform(
            name: "-なさい",
            localization: loc["-なさい"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "なさい", deinflectedSuffix: "る", conditionsIn: [.nasai], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "いなさい", deinflectedSuffix: "う", conditionsIn: [.nasai], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "きなさい", deinflectedSuffix: "く", conditionsIn: [.nasai], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ぎなさい", deinflectedSuffix: "ぐ", conditionsIn: [.nasai], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "しなさい", deinflectedSuffix: "す", conditionsIn: [.nasai], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ちなさい", deinflectedSuffix: "つ", conditionsIn: [.nasai], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "になさい", deinflectedSuffix: "ぬ", conditionsIn: [.nasai], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "びなさい", deinflectedSuffix: "ぶ", conditionsIn: [.nasai], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "みなさい", deinflectedSuffix: "む", conditionsIn: [.nasai], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "りなさい", deinflectedSuffix: "る", conditionsIn: [.nasai], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "じなさい", deinflectedSuffix: "ずる", conditionsIn: [.nasai], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "しなさい", deinflectedSuffix: "する", conditionsIn: [.nasai], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為なさい", deinflectedSuffix: "為る", conditionsIn: [.nasai], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "きなさい", deinflectedSuffix: "くる", conditionsIn: [.nasai], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来なさい", deinflectedSuffix: "来る", conditionsIn: [.nasai], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來なさい", deinflectedSuffix: "來る", conditionsIn: [.nasai], conditionsOut: [.vk]),
            ]
        )

        dict["-そう"] = Transform(
            name: "-そう",
            localization: loc["-そう"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "そう", deinflectedSuffix: "い", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "そう", deinflectedSuffix: "る", conditionsIn: [], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "いそう", deinflectedSuffix: "う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "きそう", deinflectedSuffix: "く", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ぎそう", deinflectedSuffix: "ぐ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "しそう", deinflectedSuffix: "す", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ちそう", deinflectedSuffix: "つ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "にそう", deinflectedSuffix: "ぬ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "びそう", deinflectedSuffix: "ぶ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "みそう", deinflectedSuffix: "む", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "りそう", deinflectedSuffix: "る", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "じそう", deinflectedSuffix: "ずる", conditionsIn: [], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "しそう", deinflectedSuffix: "する", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為そう", deinflectedSuffix: "為る", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "きそう", deinflectedSuffix: "くる", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来そう", deinflectedSuffix: "来る", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來そう", deinflectedSuffix: "來る", conditionsIn: [], conditionsOut: [.vk]),
            ]
        )

        dict["-すぎる"] = Transform(
            name: "-すぎる",
            localization: loc["-すぎる"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "すぎる", deinflectedSuffix: "い", conditionsIn: [.v1], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "すぎる", deinflectedSuffix: "る", conditionsIn: [.v1], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "いすぎる", deinflectedSuffix: "う", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "きすぎる", deinflectedSuffix: "く", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ぎすぎる", deinflectedSuffix: "ぐ", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "しすぎる", deinflectedSuffix: "す", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ちすぎる", deinflectedSuffix: "つ", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "にすぎる", deinflectedSuffix: "ぬ", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "びすぎる", deinflectedSuffix: "ぶ", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "みすぎる", deinflectedSuffix: "む", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "りすぎる", deinflectedSuffix: "る", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "じすぎる", deinflectedSuffix: "ずる", conditionsIn: [.v1], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "しすぎる", deinflectedSuffix: "する", conditionsIn: [.v1], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為すぎる", deinflectedSuffix: "為る", conditionsIn: [.v1], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "きすぎる", deinflectedSuffix: "くる", conditionsIn: [.v1], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来すぎる", deinflectedSuffix: "来る", conditionsIn: [.v1], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來すぎる", deinflectedSuffix: "來る", conditionsIn: [.v1], conditionsOut: [.vk]),
            ]
        )

        dict["-過ぎる"] = Transform(
            name: "-過ぎる",
            localization: loc["-過ぎる"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "過ぎる", deinflectedSuffix: "い", conditionsIn: [.v1], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "過ぎる", deinflectedSuffix: "る", conditionsIn: [.v1], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "い過ぎる", deinflectedSuffix: "う", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "き過ぎる", deinflectedSuffix: "く", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ぎ過ぎる", deinflectedSuffix: "ぐ", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "し過ぎる", deinflectedSuffix: "す", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ち過ぎる", deinflectedSuffix: "つ", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "に過ぎる", deinflectedSuffix: "ぬ", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "び過ぎる", deinflectedSuffix: "ぶ", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "み過ぎる", deinflectedSuffix: "む", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "り過ぎる", deinflectedSuffix: "る", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "じ過ぎる", deinflectedSuffix: "ずる", conditionsIn: [.v1], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "し過ぎる", deinflectedSuffix: "する", conditionsIn: [.v1], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為過ぎる", deinflectedSuffix: "為る", conditionsIn: [.v1], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "き過ぎる", deinflectedSuffix: "くる", conditionsIn: [.v1], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来過ぎる", deinflectedSuffix: "来る", conditionsIn: [.v1], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來過ぎる", deinflectedSuffix: "來る", conditionsIn: [.v1], conditionsOut: [.vk]),
            ]
        )

        dict["-たい"] = Transform(
            name: "-たい",
            localization: loc["-たい"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "たい", deinflectedSuffix: "る", conditionsIn: [.adj_i], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "いたい", deinflectedSuffix: "う", conditionsIn: [.adj_i], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "きたい", deinflectedSuffix: "く", conditionsIn: [.adj_i], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ぎたい", deinflectedSuffix: "ぐ", conditionsIn: [.adj_i], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "したい", deinflectedSuffix: "す", conditionsIn: [.adj_i], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ちたい", deinflectedSuffix: "つ", conditionsIn: [.adj_i], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "にたい", deinflectedSuffix: "ぬ", conditionsIn: [.adj_i], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "びたい", deinflectedSuffix: "ぶ", conditionsIn: [.adj_i], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "みたい", deinflectedSuffix: "む", conditionsIn: [.adj_i], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "りたい", deinflectedSuffix: "る", conditionsIn: [.adj_i], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "じたい", deinflectedSuffix: "ずる", conditionsIn: [.adj_i], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "したい", deinflectedSuffix: "する", conditionsIn: [.adj_i], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為たい", deinflectedSuffix: "為る", conditionsIn: [.adj_i], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "きたい", deinflectedSuffix: "くる", conditionsIn: [.adj_i], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来たい", deinflectedSuffix: "来る", conditionsIn: [.adj_i], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來たい", deinflectedSuffix: "來る", conditionsIn: [.adj_i], conditionsOut: [.vk]),
            ]
        )

        dict["-たら"] = Transform(
            name: "-たら",
            localization: loc["-たら"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "かったら", deinflectedSuffix: "い", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "たら", deinflectedSuffix: "る", conditionsIn: [], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "いたら", deinflectedSuffix: "く", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "いだら", deinflectedSuffix: "ぐ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "したら", deinflectedSuffix: "す", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ったら", deinflectedSuffix: "う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ったら", deinflectedSuffix: "つ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ったら", deinflectedSuffix: "る", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "んだら", deinflectedSuffix: "ぬ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "んだら", deinflectedSuffix: "ぶ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "んだら", deinflectedSuffix: "む", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "じたら", deinflectedSuffix: "ずる", conditionsIn: [], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "したら", deinflectedSuffix: "する", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為たら", deinflectedSuffix: "為る", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "きたら", deinflectedSuffix: "くる", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来たら", deinflectedSuffix: "来る", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來たら", deinflectedSuffix: "來る", conditionsIn: [], conditionsOut: [.vk]),
                // Expanded irregularVerbSuffixInflections('たら', [], ['v5'])
                SuffixRule(inflectedSuffix: "いったら", deinflectedSuffix: "いく", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "行ったら", deinflectedSuffix: "行く", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "逝ったら", deinflectedSuffix: "逝く", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "往ったら", deinflectedSuffix: "往く", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "こうたら", deinflectedSuffix: "こう", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "とうたら", deinflectedSuffix: "とう", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "請うたら", deinflectedSuffix: "請う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "乞うたら", deinflectedSuffix: "乞う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "恋うたら", deinflectedSuffix: "恋う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "問うたら", deinflectedSuffix: "問う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "訪うたら", deinflectedSuffix: "訪う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "宣うたら", deinflectedSuffix: "宣う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "曰うたら", deinflectedSuffix: "曰う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "給うたら", deinflectedSuffix: "給う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "賜うたら", deinflectedSuffix: "賜う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "揺蕩うたら", deinflectedSuffix: "揺蕩う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "のたもうたら", deinflectedSuffix: "のたまう", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "たもうたら", deinflectedSuffix: "たまう", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "たゆとうたら", deinflectedSuffix: "たゆたう", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ましたら", deinflectedSuffix: "ます", conditionsIn: [], conditionsOut: [.masu]),
            ]
        )

        dict["-たり"] = Transform(
            name: "-たり",
            localization: loc["-たり"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "かったり", deinflectedSuffix: "い", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "たり", deinflectedSuffix: "る", conditionsIn: [], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "いたり", deinflectedSuffix: "く", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "いだり", deinflectedSuffix: "ぐ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "したり", deinflectedSuffix: "す", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ったり", deinflectedSuffix: "う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ったり", deinflectedSuffix: "つ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ったり", deinflectedSuffix: "る", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "んだり", deinflectedSuffix: "ぬ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "んだり", deinflectedSuffix: "ぶ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "んだり", deinflectedSuffix: "む", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "じたり", deinflectedSuffix: "ずる", conditionsIn: [], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "したり", deinflectedSuffix: "する", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為たり", deinflectedSuffix: "為る", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "きたり", deinflectedSuffix: "くる", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来たり", deinflectedSuffix: "来る", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來たり", deinflectedSuffix: "來る", conditionsIn: [], conditionsOut: [.vk]),
                // Expanded irregularVerbSuffixInflections('たり', [], ['v5'])
                SuffixRule(inflectedSuffix: "いったり", deinflectedSuffix: "いく", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "行ったり", deinflectedSuffix: "行く", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "逝ったり", deinflectedSuffix: "逝く", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "往ったり", deinflectedSuffix: "往く", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "こうたり", deinflectedSuffix: "こう", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "とうたり", deinflectedSuffix: "とう", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "請うたり", deinflectedSuffix: "請う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "乞うたり", deinflectedSuffix: "乞う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "恋うたり", deinflectedSuffix: "恋う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "問うたり", deinflectedSuffix: "問う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "訪うたり", deinflectedSuffix: "訪う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "宣うたり", deinflectedSuffix: "宣う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "曰うたり", deinflectedSuffix: "曰う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "給うたり", deinflectedSuffix: "給う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "賜うたり", deinflectedSuffix: "賜う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "揺蕩うたり", deinflectedSuffix: "揺蕩う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "のたもうたり", deinflectedSuffix: "のたまう", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "たもうたり", deinflectedSuffix: "たまう", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "たゆとうたり", deinflectedSuffix: "たゆたう", conditionsIn: [], conditionsOut: [.v5]),
            ]
        )

        dict["-て"] = Transform(
            name: "-て",
            localization: loc["-て"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "くて", deinflectedSuffix: "い", conditionsIn: [.te], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "て", deinflectedSuffix: "る", conditionsIn: [.te], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "いて", deinflectedSuffix: "く", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "いで", deinflectedSuffix: "ぐ", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "して", deinflectedSuffix: "す", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "って", deinflectedSuffix: "う", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "って", deinflectedSuffix: "つ", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "って", deinflectedSuffix: "る", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "んで", deinflectedSuffix: "ぬ", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "んで", deinflectedSuffix: "ぶ", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "んで", deinflectedSuffix: "む", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "じて", deinflectedSuffix: "ずる", conditionsIn: [.te], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "して", deinflectedSuffix: "する", conditionsIn: [.te], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為て", deinflectedSuffix: "為る", conditionsIn: [.te], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "きて", deinflectedSuffix: "くる", conditionsIn: [.te], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来て", deinflectedSuffix: "来る", conditionsIn: [.te], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來て", deinflectedSuffix: "來る", conditionsIn: [.te], conditionsOut: [.vk]),
                // Expanded irregularVerbSuffixInflections('て', [.te], [.v5])
                SuffixRule(inflectedSuffix: "いって", deinflectedSuffix: "いく", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "行って", deinflectedSuffix: "行く", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "逝って", deinflectedSuffix: "逝く", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "往って", deinflectedSuffix: "往く", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "こうて", deinflectedSuffix: "こう", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "とうて", deinflectedSuffix: "とう", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "請うて", deinflectedSuffix: "請う", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "乞うて", deinflectedSuffix: "乞う", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "恋うて", deinflectedSuffix: "恋う", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "問うて", deinflectedSuffix: "問う", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "訪うて", deinflectedSuffix: "訪う", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "宣うて", deinflectedSuffix: "宣う", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "曰うて", deinflectedSuffix: "曰う", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "給うて", deinflectedSuffix: "給う", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "賜うて", deinflectedSuffix: "賜う", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "揺蕩うて", deinflectedSuffix: "揺蕩う", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "のたもうて", deinflectedSuffix: "のたまう", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "たもうて", deinflectedSuffix: "たまう", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "たゆとうて", deinflectedSuffix: "たゆたう", conditionsIn: [.te], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "まして", deinflectedSuffix: "ます", conditionsIn: [], conditionsOut: [.masu]),
            ]
        )

        dict["-ず"] = Transform(
            name: "-ず",
            localization: loc["-ず"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "ず", deinflectedSuffix: "る", conditionsIn: [], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "かず", deinflectedSuffix: "く", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "がず", deinflectedSuffix: "ぐ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "さず", deinflectedSuffix: "す", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "たず", deinflectedSuffix: "つ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "なず", deinflectedSuffix: "ぬ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ばず", deinflectedSuffix: "ぶ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "まず", deinflectedSuffix: "む", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "らず", deinflectedSuffix: "る", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "わず", deinflectedSuffix: "う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ぜず", deinflectedSuffix: "ずる", conditionsIn: [], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "せず", deinflectedSuffix: "する", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為ず", deinflectedSuffix: "為る", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "こず", deinflectedSuffix: "くる", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来ず", deinflectedSuffix: "来る", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來ず", deinflectedSuffix: "來る", conditionsIn: [], conditionsOut: [.vk]),
            ]
        )

        dict["-ぬ"] = Transform(
            name: "-ぬ",
            localization: loc["-ぬ"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "ぬ", deinflectedSuffix: "る", conditionsIn: [], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "かぬ", deinflectedSuffix: "く", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "がぬ", deinflectedSuffix: "ぐ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "さぬ", deinflectedSuffix: "す", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "たぬ", deinflectedSuffix: "つ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "なぬ", deinflectedSuffix: "ぬ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ばぬ", deinflectedSuffix: "ぶ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "まぬ", deinflectedSuffix: "む", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "らぬ", deinflectedSuffix: "る", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "わぬ", deinflectedSuffix: "う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ぜぬ", deinflectedSuffix: "ずる", conditionsIn: [], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "せぬ", deinflectedSuffix: "する", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為ぬ", deinflectedSuffix: "為る", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "こぬ", deinflectedSuffix: "くる", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来ぬ", deinflectedSuffix: "来る", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來ぬ", deinflectedSuffix: "來る", conditionsIn: [], conditionsOut: [.vk]),
            ]
        )

        dict["-ん"] = Transform(
            name: "-ん",
            localization: loc["-ん"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "ん", deinflectedSuffix: "る", conditionsIn: [.n], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "かん", deinflectedSuffix: "く", conditionsIn: [.n], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "がん", deinflectedSuffix: "ぐ", conditionsIn: [.n], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "さん", deinflectedSuffix: "す", conditionsIn: [.n], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "たん", deinflectedSuffix: "つ", conditionsIn: [.n], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "なん", deinflectedSuffix: "ぬ", conditionsIn: [.n], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ばん", deinflectedSuffix: "ぶ", conditionsIn: [.n], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "まん", deinflectedSuffix: "む", conditionsIn: [.n], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "らん", deinflectedSuffix: "る", conditionsIn: [.n], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "わん", deinflectedSuffix: "う", conditionsIn: [.n], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ぜん", deinflectedSuffix: "ずる", conditionsIn: [.n], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "せん", deinflectedSuffix: "する", conditionsIn: [.n], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為ん", deinflectedSuffix: "為る", conditionsIn: [.n], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "こん", deinflectedSuffix: "くる", conditionsIn: [.n], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来ん", deinflectedSuffix: "来る", conditionsIn: [.n], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來ん", deinflectedSuffix: "來る", conditionsIn: [.n], conditionsOut: [.vk]),
            ]
        )

        dict["-んばかり"] = Transform(
            name: "-んばかり",
            localization: loc["-んばかり"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "んばかり", deinflectedSuffix: "る", conditionsIn: [], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "かんばかり", deinflectedSuffix: "く", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "がんばかり", deinflectedSuffix: "ぐ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "さんばかり", deinflectedSuffix: "す", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "たんばかり", deinflectedSuffix: "つ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "なんばかり", deinflectedSuffix: "ぬ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ばんばかり", deinflectedSuffix: "ぶ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "まんばかり", deinflectedSuffix: "む", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "らんばかり", deinflectedSuffix: "る", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "わんばかり", deinflectedSuffix: "う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ぜんばかり", deinflectedSuffix: "ずる", conditionsIn: [], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "せんばかり", deinflectedSuffix: "する", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為んばかり", deinflectedSuffix: "為る", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "こんばかり", deinflectedSuffix: "くる", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来んばかり", deinflectedSuffix: "来る", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來んばかり", deinflectedSuffix: "來る", conditionsIn: [], conditionsOut: [.vk]),
            ]
        )

        dict["-んとする"] = Transform(
            name: "-んとする",
            localization: loc["-んとする"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "んとする", deinflectedSuffix: "る", conditionsIn: [.vs], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "かんとする", deinflectedSuffix: "く", conditionsIn: [.vs], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "がんとする", deinflectedSuffix: "ぐ", conditionsIn: [.vs], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "さんとする", deinflectedSuffix: "す", conditionsIn: [.vs], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "たんとする", deinflectedSuffix: "つ", conditionsIn: [.vs], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "なんとする", deinflectedSuffix: "ぬ", conditionsIn: [.vs], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ばんとする", deinflectedSuffix: "ぶ", conditionsIn: [.vs], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "まんとする", deinflectedSuffix: "む", conditionsIn: [.vs], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "らんとする", deinflectedSuffix: "る", conditionsIn: [.vs], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "わんとする", deinflectedSuffix: "う", conditionsIn: [.vs], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ぜんとする", deinflectedSuffix: "ずる", conditionsIn: [.vs], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "せんとする", deinflectedSuffix: "する", conditionsIn: [.vs], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為んとする", deinflectedSuffix: "為る", conditionsIn: [.vs], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "こんとする", deinflectedSuffix: "くる", conditionsIn: [.vs], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来んとする", deinflectedSuffix: "来る", conditionsIn: [.vs], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來んとする", deinflectedSuffix: "來る", conditionsIn: [.vs], conditionsOut: [.vk]),
            ]
        )

        dict["-む"] = Transform(
            name: "-む",
            localization: loc["-む"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "む", deinflectedSuffix: "る", conditionsIn: [], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "かむ", deinflectedSuffix: "く", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "がむ", deinflectedSuffix: "ぐ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "さむ", deinflectedSuffix: "す", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "たむ", deinflectedSuffix: "つ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "なむ", deinflectedSuffix: "ぬ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ばむ", deinflectedSuffix: "ぶ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "まむ", deinflectedSuffix: "む", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "らむ", deinflectedSuffix: "る", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "わむ", deinflectedSuffix: "う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ぜむ", deinflectedSuffix: "ずる", conditionsIn: [], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "せむ", deinflectedSuffix: "する", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為む", deinflectedSuffix: "為る", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "こむ", deinflectedSuffix: "くる", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来む", deinflectedSuffix: "来る", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來む", deinflectedSuffix: "來る", conditionsIn: [], conditionsOut: [.vk]),
            ]
        )

        dict["-ざる"] = Transform(
            name: "-ざる",
            localization: loc["-ざる"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "ざる", deinflectedSuffix: "る", conditionsIn: [], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "かざる", deinflectedSuffix: "く", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "がざる", deinflectedSuffix: "ぐ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "さざる", deinflectedSuffix: "す", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "たざる", deinflectedSuffix: "つ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "なざる", deinflectedSuffix: "ぬ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ばざる", deinflectedSuffix: "ぶ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "まざる", deinflectedSuffix: "む", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "らざる", deinflectedSuffix: "る", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "わざる", deinflectedSuffix: "う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ぜざる", deinflectedSuffix: "ずる", conditionsIn: [], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "せざる", deinflectedSuffix: "する", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為ざる", deinflectedSuffix: "為る", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "こざる", deinflectedSuffix: "くる", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来ざる", deinflectedSuffix: "来る", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來ざる", deinflectedSuffix: "來る", conditionsIn: [], conditionsOut: [.vk]),
            ]
        )

        dict["-ねば"] = Transform(
            name: "-ねば",
            localization: loc["-ねば"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "ねば", deinflectedSuffix: "る", conditionsIn: [.ba], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "かねば", deinflectedSuffix: "く", conditionsIn: [.ba], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "がねば", deinflectedSuffix: "ぐ", conditionsIn: [.ba], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "さねば", deinflectedSuffix: "す", conditionsIn: [.ba], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "たねば", deinflectedSuffix: "つ", conditionsIn: [.ba], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "なねば", deinflectedSuffix: "ぬ", conditionsIn: [.ba], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ばねば", deinflectedSuffix: "ぶ", conditionsIn: [.ba], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "まねば", deinflectedSuffix: "む", conditionsIn: [.ba], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "らねば", deinflectedSuffix: "る", conditionsIn: [.ba], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "わねば", deinflectedSuffix: "う", conditionsIn: [.ba], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ぜねば", deinflectedSuffix: "ずる", conditionsIn: [.ba], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "せねば", deinflectedSuffix: "する", conditionsIn: [.ba], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為ねば", deinflectedSuffix: "為る", conditionsIn: [.ba], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "こねば", deinflectedSuffix: "くる", conditionsIn: [.ba], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来ねば", deinflectedSuffix: "来る", conditionsIn: [.ba], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來ねば", deinflectedSuffix: "來る", conditionsIn: [.ba], conditionsOut: [.vk]),
            ]
        )

        dict["-く"] = Transform(
            name: "-く",
            localization: loc["-く"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "く", deinflectedSuffix: "い", conditionsIn: [.ku], conditionsOut: [.adj_i]),
            ]
        )

        dict["causative"] = Transform(
            name: "causative",
            localization: loc["causative"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "させる", deinflectedSuffix: "る", conditionsIn: [.v1], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "かせる", deinflectedSuffix: "く", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "がせる", deinflectedSuffix: "ぐ", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "させる", deinflectedSuffix: "す", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "たせる", deinflectedSuffix: "つ", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "なせる", deinflectedSuffix: "ぬ", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ばせる", deinflectedSuffix: "ぶ", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ませる", deinflectedSuffix: "む", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "らせる", deinflectedSuffix: "る", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "わせる", deinflectedSuffix: "う", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "じさせる", deinflectedSuffix: "ずる", conditionsIn: [.v1], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "ぜさせる", deinflectedSuffix: "ずる", conditionsIn: [.v1], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "させる", deinflectedSuffix: "する", conditionsIn: [.v1], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為せる", deinflectedSuffix: "為る", conditionsIn: [.v1], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "せさせる", deinflectedSuffix: "する", conditionsIn: [.v1], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為させる", deinflectedSuffix: "為る", conditionsIn: [.v1], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "こさせる", deinflectedSuffix: "くる", conditionsIn: [.v1], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来させる", deinflectedSuffix: "来る", conditionsIn: [.v1], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來させる", deinflectedSuffix: "來る", conditionsIn: [.v1], conditionsOut: [.vk]),
            ]
        )

        dict["short causative"] = Transform(
            name: "short causative",
            localization: loc["short causative"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "さす", deinflectedSuffix: "る", conditionsIn: [.v5ss], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "かす", deinflectedSuffix: "く", conditionsIn: [.v5sp], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "がす", deinflectedSuffix: "ぐ", conditionsIn: [.v5sp], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "さす", deinflectedSuffix: "す", conditionsIn: [.v5ss], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "たす", deinflectedSuffix: "つ", conditionsIn: [.v5sp], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "なす", deinflectedSuffix: "ぬ", conditionsIn: [.v5sp], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ばす", deinflectedSuffix: "ぶ", conditionsIn: [.v5sp], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ます", deinflectedSuffix: "む", conditionsIn: [.v5sp], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "らす", deinflectedSuffix: "る", conditionsIn: [.v5sp], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "わす", deinflectedSuffix: "う", conditionsIn: [.v5sp], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "じさす", deinflectedSuffix: "ずる", conditionsIn: [.v5ss], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "ぜさす", deinflectedSuffix: "ずる", conditionsIn: [.v5ss], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "さす", deinflectedSuffix: "する", conditionsIn: [.v5ss], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為す", deinflectedSuffix: "為る", conditionsIn: [.v5ss], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "こさす", deinflectedSuffix: "くる", conditionsIn: [.v5ss], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来さす", deinflectedSuffix: "来る", conditionsIn: [.v5ss], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來さす", deinflectedSuffix: "來る", conditionsIn: [.v5ss], conditionsOut: [.vk]),
            ]
        )

        dict["imperative"] = Transform(
            name: "imperative",
            localization: loc["imperative"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "ろ", deinflectedSuffix: "る", conditionsIn: [], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "よ", deinflectedSuffix: "る", conditionsIn: [], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "え", deinflectedSuffix: "う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "け", deinflectedSuffix: "く", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "げ", deinflectedSuffix: "ぐ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "せ", deinflectedSuffix: "す", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "て", deinflectedSuffix: "つ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ね", deinflectedSuffix: "ぬ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "べ", deinflectedSuffix: "ぶ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "め", deinflectedSuffix: "む", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "れ", deinflectedSuffix: "る", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "じろ", deinflectedSuffix: "ずる", conditionsIn: [], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "ぜよ", deinflectedSuffix: "ずる", conditionsIn: [], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "しろ", deinflectedSuffix: "する", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "せよ", deinflectedSuffix: "する", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為ろ", deinflectedSuffix: "為る", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為よ", deinflectedSuffix: "為る", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "こい", deinflectedSuffix: "くる", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来い", deinflectedSuffix: "来る", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來い", deinflectedSuffix: "來る", conditionsIn: [], conditionsOut: [.vk]),
            ]
        )

        dict["continuative"] = Transform(
            name: "continuative",
            localization: loc["continuative"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "い", deinflectedSuffix: "いる", conditionsIn: [], conditionsOut: [.v1d]),
                SuffixRule(inflectedSuffix: "え", deinflectedSuffix: "える", conditionsIn: [], conditionsOut: [.v1d]),
                SuffixRule(inflectedSuffix: "き", deinflectedSuffix: "きる", conditionsIn: [], conditionsOut: [.v1d]),
                SuffixRule(inflectedSuffix: "ぎ", deinflectedSuffix: "ぎる", conditionsIn: [], conditionsOut: [.v1d]),
                SuffixRule(inflectedSuffix: "け", deinflectedSuffix: "ける", conditionsIn: [], conditionsOut: [.v1d]),
                SuffixRule(inflectedSuffix: "げ", deinflectedSuffix: "げる", conditionsIn: [], conditionsOut: [.v1d]),
                SuffixRule(inflectedSuffix: "じ", deinflectedSuffix: "じる", conditionsIn: [], conditionsOut: [.v1d]),
                SuffixRule(inflectedSuffix: "せ", deinflectedSuffix: "せる", conditionsIn: [], conditionsOut: [.v1d]),
                SuffixRule(inflectedSuffix: "ぜ", deinflectedSuffix: "ぜる", conditionsIn: [], conditionsOut: [.v1d]),
                SuffixRule(inflectedSuffix: "ち", deinflectedSuffix: "ちる", conditionsIn: [], conditionsOut: [.v1d]),
                SuffixRule(inflectedSuffix: "て", deinflectedSuffix: "てる", conditionsIn: [], conditionsOut: [.v1d]),
                SuffixRule(inflectedSuffix: "で", deinflectedSuffix: "でる", conditionsIn: [], conditionsOut: [.v1d]),
                SuffixRule(inflectedSuffix: "に", deinflectedSuffix: "にる", conditionsIn: [], conditionsOut: [.v1d]),
                SuffixRule(inflectedSuffix: "ね", deinflectedSuffix: "ねる", conditionsIn: [], conditionsOut: [.v1d]),
                SuffixRule(inflectedSuffix: "ひ", deinflectedSuffix: "ひる", conditionsIn: [], conditionsOut: [.v1d]),
                SuffixRule(inflectedSuffix: "び", deinflectedSuffix: "びる", conditionsIn: [], conditionsOut: [.v1d]),
                SuffixRule(inflectedSuffix: "へ", deinflectedSuffix: "へる", conditionsIn: [], conditionsOut: [.v1d]),
                SuffixRule(inflectedSuffix: "べ", deinflectedSuffix: "べる", conditionsIn: [], conditionsOut: [.v1d]),
                SuffixRule(inflectedSuffix: "み", deinflectedSuffix: "みる", conditionsIn: [], conditionsOut: [.v1d]),
                SuffixRule(inflectedSuffix: "め", deinflectedSuffix: "める", conditionsIn: [], conditionsOut: [.v1d]),
                SuffixRule(inflectedSuffix: "り", deinflectedSuffix: "りる", conditionsIn: [], conditionsOut: [.v1d]),
                SuffixRule(inflectedSuffix: "れ", deinflectedSuffix: "れる", conditionsIn: [], conditionsOut: [.v1d]),
                SuffixRule(inflectedSuffix: "い", deinflectedSuffix: "う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "き", deinflectedSuffix: "く", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ぎ", deinflectedSuffix: "ぐ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "し", deinflectedSuffix: "す", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ち", deinflectedSuffix: "つ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "に", deinflectedSuffix: "ぬ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "び", deinflectedSuffix: "ぶ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "み", deinflectedSuffix: "む", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "り", deinflectedSuffix: "る", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "き", deinflectedSuffix: "くる", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "し", deinflectedSuffix: "する", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "来", deinflectedSuffix: "来る", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來", deinflectedSuffix: "來る", conditionsIn: [], conditionsOut: [.vk]),
            ]
        )

        dict["negative"] = Transform(
            name: "negative",
            localization: loc["negative"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "くない", deinflectedSuffix: "い", conditionsIn: [.adj_i], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "ない", deinflectedSuffix: "る", conditionsIn: [.adj_i], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "かない", deinflectedSuffix: "く", conditionsIn: [.adj_i], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "がない", deinflectedSuffix: "ぐ", conditionsIn: [.adj_i], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "さない", deinflectedSuffix: "す", conditionsIn: [.adj_i], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "たない", deinflectedSuffix: "つ", conditionsIn: [.adj_i], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "なない", deinflectedSuffix: "ぬ", conditionsIn: [.adj_i], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ばない", deinflectedSuffix: "ぶ", conditionsIn: [.adj_i], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "まない", deinflectedSuffix: "む", conditionsIn: [.adj_i], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "らない", deinflectedSuffix: "る", conditionsIn: [.adj_i], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "わない", deinflectedSuffix: "う", conditionsIn: [.adj_i], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "じない", deinflectedSuffix: "ずる", conditionsIn: [.adj_i], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "しない", deinflectedSuffix: "する", conditionsIn: [.adj_i], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為ない", deinflectedSuffix: "為る", conditionsIn: [.adj_i], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "こない", deinflectedSuffix: "くる", conditionsIn: [.adj_i], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来ない", deinflectedSuffix: "来る", conditionsIn: [.adj_i], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來ない", deinflectedSuffix: "來る", conditionsIn: [.adj_i], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "ません", deinflectedSuffix: "ます", conditionsIn: [.masen], conditionsOut: [.masu]),
            ]
        )

        dict["-さ"] = Transform(
            name: "-さ",
            localization: loc["-さ"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "さ", deinflectedSuffix: "い", conditionsIn: [], conditionsOut: [.adj_i]),
            ]
        )

        dict["passive"] = Transform(
            name: "passive",
            localization: loc["passive"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "かれる", deinflectedSuffix: "く", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "がれる", deinflectedSuffix: "ぐ", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "される", deinflectedSuffix: "す", conditionsIn: [.v1], conditionsOut: [.v5d, .v5sp]),
                SuffixRule(inflectedSuffix: "たれる", deinflectedSuffix: "つ", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "なれる", deinflectedSuffix: "ぬ", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ばれる", deinflectedSuffix: "ぶ", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "まれる", deinflectedSuffix: "む", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "われる", deinflectedSuffix: "う", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "られる", deinflectedSuffix: "る", conditionsIn: [.v1], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "じされる", deinflectedSuffix: "ずる", conditionsIn: [.v1], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "ぜされる", deinflectedSuffix: "ずる", conditionsIn: [.v1], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "される", deinflectedSuffix: "する", conditionsIn: [.v1], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為れる", deinflectedSuffix: "為る", conditionsIn: [.v1], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "こられる", deinflectedSuffix: "くる", conditionsIn: [.v1], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来られる", deinflectedSuffix: "来る", conditionsIn: [.v1], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來られる", deinflectedSuffix: "來る", conditionsIn: [.v1], conditionsOut: [.vk]),
            ]
        )

        dict["-た"] = Transform(
            name: "-た",
            localization: loc["-た"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "かった", deinflectedSuffix: "い", conditionsIn: [.ta], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "た", deinflectedSuffix: "る", conditionsIn: [.ta], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "いた", deinflectedSuffix: "く", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "いだ", deinflectedSuffix: "ぐ", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "した", deinflectedSuffix: "す", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "った", deinflectedSuffix: "う", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "った", deinflectedSuffix: "つ", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "った", deinflectedSuffix: "る", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "んだ", deinflectedSuffix: "ぬ", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "んだ", deinflectedSuffix: "ぶ", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "んだ", deinflectedSuffix: "む", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "じた", deinflectedSuffix: "ずる", conditionsIn: [.ta], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "した", deinflectedSuffix: "する", conditionsIn: [.ta], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為た", deinflectedSuffix: "為る", conditionsIn: [.ta], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "きた", deinflectedSuffix: "くる", conditionsIn: [.ta], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来た", deinflectedSuffix: "来る", conditionsIn: [.ta], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來た", deinflectedSuffix: "來る", conditionsIn: [.ta], conditionsOut: [.vk]),
                // Expanded irregularVerbSuffixInflections('た', [.ta], [.v5])
                SuffixRule(inflectedSuffix: "いった", deinflectedSuffix: "いく", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "行った", deinflectedSuffix: "行く", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "逝った", deinflectedSuffix: "逝く", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "往った", deinflectedSuffix: "往く", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "こうた", deinflectedSuffix: "こう", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "とうた", deinflectedSuffix: "とう", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "請うた", deinflectedSuffix: "請う", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "乞うた", deinflectedSuffix: "乞う", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "恋うた", deinflectedSuffix: "恋う", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "問うた", deinflectedSuffix: "問う", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "訪うた", deinflectedSuffix: "訪う", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "宣うた", deinflectedSuffix: "宣う", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "曰うた", deinflectedSuffix: "曰う", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "給うた", deinflectedSuffix: "給う", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "賜うた", deinflectedSuffix: "賜う", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "揺蕩うた", deinflectedSuffix: "揺蕩う", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "のたもうた", deinflectedSuffix: "のたまう", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "たもうた", deinflectedSuffix: "たまう", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "たゆとうた", deinflectedSuffix: "たゆたう", conditionsIn: [.ta], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ました", deinflectedSuffix: "ます", conditionsIn: [.ta], conditionsOut: [.masu]),
                SuffixRule(inflectedSuffix: "でした", deinflectedSuffix: "", conditionsIn: [.ta], conditionsOut: [.masen]),
                SuffixRule(inflectedSuffix: "かった", deinflectedSuffix: "", conditionsIn: [.ta], conditionsOut: [.masen, .n]),
            ]
        )

        dict["-ます"] = Transform(
            name: "-ます",
            localization: loc["-ます"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "ます", deinflectedSuffix: "る", conditionsIn: [.masu], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "います", deinflectedSuffix: "う", conditionsIn: [.masu], conditionsOut: [.v5d]),
                SuffixRule(inflectedSuffix: "きます", deinflectedSuffix: "く", conditionsIn: [.masu], conditionsOut: [.v5d]),
                SuffixRule(inflectedSuffix: "ぎます", deinflectedSuffix: "ぐ", conditionsIn: [.masu], conditionsOut: [.v5d]),
                SuffixRule(inflectedSuffix: "します", deinflectedSuffix: "す", conditionsIn: [.masu], conditionsOut: [.v5d, .v5s]),
                SuffixRule(inflectedSuffix: "ちます", deinflectedSuffix: "つ", conditionsIn: [.masu], conditionsOut: [.v5d]),
                SuffixRule(inflectedSuffix: "にます", deinflectedSuffix: "ぬ", conditionsIn: [.masu], conditionsOut: [.v5d]),
                SuffixRule(inflectedSuffix: "びます", deinflectedSuffix: "ぶ", conditionsIn: [.masu], conditionsOut: [.v5d]),
                SuffixRule(inflectedSuffix: "みます", deinflectedSuffix: "む", conditionsIn: [.masu], conditionsOut: [.v5d]),
                SuffixRule(inflectedSuffix: "ります", deinflectedSuffix: "る", conditionsIn: [.masu], conditionsOut: [.v5d]),
                SuffixRule(inflectedSuffix: "じます", deinflectedSuffix: "ずる", conditionsIn: [.masu], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "します", deinflectedSuffix: "する", conditionsIn: [.masu], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為ます", deinflectedSuffix: "為る", conditionsIn: [.masu], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "きます", deinflectedSuffix: "くる", conditionsIn: [.masu], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来ます", deinflectedSuffix: "来る", conditionsIn: [.masu], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來ます", deinflectedSuffix: "來る", conditionsIn: [.masu], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "くあります", deinflectedSuffix: "い", conditionsIn: [.masu], conditionsOut: [.adj_i]),
            ]
        )

        dict["potential"] = Transform(
            name: "potential",
            localization: loc["potential"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "れる", deinflectedSuffix: "る", conditionsIn: [.v1], conditionsOut: [.v1, .v5d]),
                SuffixRule(inflectedSuffix: "える", deinflectedSuffix: "う", conditionsIn: [.v1], conditionsOut: [.v5d]),
                SuffixRule(inflectedSuffix: "ける", deinflectedSuffix: "く", conditionsIn: [.v1], conditionsOut: [.v5d]),
                SuffixRule(inflectedSuffix: "げる", deinflectedSuffix: "ぐ", conditionsIn: [.v1], conditionsOut: [.v5d]),
                SuffixRule(inflectedSuffix: "せる", deinflectedSuffix: "す", conditionsIn: [.v1], conditionsOut: [.v5d]),
                SuffixRule(inflectedSuffix: "てる", deinflectedSuffix: "つ", conditionsIn: [.v1], conditionsOut: [.v5d]),
                SuffixRule(inflectedSuffix: "ねる", deinflectedSuffix: "ぬ", conditionsIn: [.v1], conditionsOut: [.v5d]),
                SuffixRule(inflectedSuffix: "べる", deinflectedSuffix: "ぶ", conditionsIn: [.v1], conditionsOut: [.v5d]),
                SuffixRule(inflectedSuffix: "める", deinflectedSuffix: "む", conditionsIn: [.v1], conditionsOut: [.v5d]),
                SuffixRule(inflectedSuffix: "できる", deinflectedSuffix: "する", conditionsIn: [.v1], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "出来る", deinflectedSuffix: "する", conditionsIn: [.v1], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "これる", deinflectedSuffix: "くる", conditionsIn: [.v1], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来れる", deinflectedSuffix: "来る", conditionsIn: [.v1], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來れる", deinflectedSuffix: "來る", conditionsIn: [.v1], conditionsOut: [.vk]),
            ]
        )

        dict["potential or passive"] = Transform(
            name: "potential or passive",
            localization: loc["potential or passive"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "られる", deinflectedSuffix: "る", conditionsIn: [.v1], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "ざれる", deinflectedSuffix: "ずる", conditionsIn: [.v1], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "ぜられる", deinflectedSuffix: "ずる", conditionsIn: [.v1], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "せられる", deinflectedSuffix: "する", conditionsIn: [.v1], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為られる", deinflectedSuffix: "為る", conditionsIn: [.v1], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "こられる", deinflectedSuffix: "くる", conditionsIn: [.v1], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来られる", deinflectedSuffix: "来る", conditionsIn: [.v1], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來られる", deinflectedSuffix: "來る", conditionsIn: [.v1], conditionsOut: [.vk]),
            ]
        )

        dict["volitional"] = Transform(
            name: "volitional",
            localization: loc["volitional"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "よう", deinflectedSuffix: "る", conditionsIn: [], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "おう", deinflectedSuffix: "う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "こう", deinflectedSuffix: "く", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ごう", deinflectedSuffix: "ぐ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "そう", deinflectedSuffix: "す", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "とう", deinflectedSuffix: "つ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "のう", deinflectedSuffix: "ぬ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ぼう", deinflectedSuffix: "ぶ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "もう", deinflectedSuffix: "む", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ろう", deinflectedSuffix: "る", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "じよう", deinflectedSuffix: "ずる", conditionsIn: [], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "しよう", deinflectedSuffix: "する", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為よう", deinflectedSuffix: "為る", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "こよう", deinflectedSuffix: "くる", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来よう", deinflectedSuffix: "来る", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來よう", deinflectedSuffix: "來る", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "ましょう", deinflectedSuffix: "ます", conditionsIn: [], conditionsOut: [.masu]),
                SuffixRule(inflectedSuffix: "かろう", deinflectedSuffix: "い", conditionsIn: [], conditionsOut: [.adj_i]),
            ]
        )

        dict["volitional slang"] = Transform(
            name: "volitional slang",
            localization: loc["volitional slang"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "よっか", deinflectedSuffix: "る", conditionsIn: [], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "おっか", deinflectedSuffix: "う", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "こっか", deinflectedSuffix: "く", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ごっか", deinflectedSuffix: "ぐ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "そっか", deinflectedSuffix: "す", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "とっか", deinflectedSuffix: "つ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "のっか", deinflectedSuffix: "ぬ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ぼっか", deinflectedSuffix: "ぶ", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "もっか", deinflectedSuffix: "む", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "ろっか", deinflectedSuffix: "る", conditionsIn: [], conditionsOut: [.v5]),
                SuffixRule(inflectedSuffix: "じよっか", deinflectedSuffix: "ずる", conditionsIn: [], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "しよっか", deinflectedSuffix: "する", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為よっか", deinflectedSuffix: "為る", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "こよっか", deinflectedSuffix: "くる", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来よっか", deinflectedSuffix: "来る", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來よっか", deinflectedSuffix: "來る", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "ましょっか", deinflectedSuffix: "ます", conditionsIn: [], conditionsOut: [.masu]),
            ]
        )

        dict["-まい"] = Transform(
            name: "-まい",
            localization: loc["-まい"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "まい", deinflectedSuffix: "", conditionsIn: [], conditionsOut: [.v]),
                SuffixRule(inflectedSuffix: "まい", deinflectedSuffix: "る", conditionsIn: [], conditionsOut: [.v1]),
                SuffixRule(inflectedSuffix: "じまい", deinflectedSuffix: "ずる", conditionsIn: [], conditionsOut: [.vz]),
                SuffixRule(inflectedSuffix: "しまい", deinflectedSuffix: "する", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "為まい", deinflectedSuffix: "為る", conditionsIn: [], conditionsOut: [.vs]),
                SuffixRule(inflectedSuffix: "こまい", deinflectedSuffix: "くる", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "来まい", deinflectedSuffix: "来る", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "來まい", deinflectedSuffix: "來る", conditionsIn: [], conditionsOut: [.vk]),
                SuffixRule(inflectedSuffix: "まい", deinflectedSuffix: "", conditionsIn: [], conditionsOut: [.masu]),
            ]
        )

        dict["-おく"] = Transform(
            name: "-おく",
            localization: loc["-おく"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "ておく", deinflectedSuffix: "て", conditionsIn: [.v5], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "でおく", deinflectedSuffix: "で", conditionsIn: [.v5], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "とく", deinflectedSuffix: "て", conditionsIn: [.v5], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "どく", deinflectedSuffix: "で", conditionsIn: [.v5], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "ないでおく", deinflectedSuffix: "ない", conditionsIn: [.v5], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "ないどく", deinflectedSuffix: "ない", conditionsIn: [.v5], conditionsOut: [.adj_i]),
            ]
        )

        dict["-いる"] = Transform(
            name: "-いる",
            localization: loc["-いる"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "ている", deinflectedSuffix: "て", conditionsIn: [.v1], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "ておる", deinflectedSuffix: "て", conditionsIn: [.v5], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "てる", deinflectedSuffix: "て", conditionsIn: [.v1p], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "でいる", deinflectedSuffix: "で", conditionsIn: [.v1], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "でおる", deinflectedSuffix: "で", conditionsIn: [.v5], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "でる", deinflectedSuffix: "で", conditionsIn: [.v1p], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "とる", deinflectedSuffix: "て", conditionsIn: [.v5], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "ないでいる", deinflectedSuffix: "ない", conditionsIn: [.v1], conditionsOut: [.adj_i]),
            ]
        )

        dict["-き"] = Transform(
            name: "-き",
            localization: loc["-き"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "き", deinflectedSuffix: "い", conditionsIn: [], conditionsOut: [.adj_i]),
            ]
        )

        dict["-げ"] = Transform(
            name: "-げ",
            localization: loc["-げ"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "げ", deinflectedSuffix: "い", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "気", deinflectedSuffix: "い", conditionsIn: [], conditionsOut: [.adj_i]),
            ]
        )

        dict["-がる"] = Transform(
            name: "-がる",
            localization: loc["-がる"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "がる", deinflectedSuffix: "い", conditionsIn: [.v5], conditionsOut: [.adj_i]),
            ]
        )

        dict["-え"] = Transform(
            name: "-え",
            localization: loc["-え"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "ねえ", deinflectedSuffix: "ない", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "めえ", deinflectedSuffix: "むい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "みい", deinflectedSuffix: "むい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "ちぇえ", deinflectedSuffix: "つい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "ちい", deinflectedSuffix: "つい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "せえ", deinflectedSuffix: "すい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "ええ", deinflectedSuffix: "いい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "ええ", deinflectedSuffix: "わい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "ええ", deinflectedSuffix: "よい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "いぇえ", deinflectedSuffix: "よい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "うぇえ", deinflectedSuffix: "わい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "けえ", deinflectedSuffix: "かい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "げえ", deinflectedSuffix: "がい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "げえ", deinflectedSuffix: "ごい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "せえ", deinflectedSuffix: "さい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "めえ", deinflectedSuffix: "まい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "ぜえ", deinflectedSuffix: "ずい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "っぜえ", deinflectedSuffix: "ずい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "れえ", deinflectedSuffix: "らい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "れえ", deinflectedSuffix: "らい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "ちぇえ", deinflectedSuffix: "ちゃい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "でえ", deinflectedSuffix: "どい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "れえ", deinflectedSuffix: "れい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "べえ", deinflectedSuffix: "ばい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "てえ", deinflectedSuffix: "たい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "ねぇ", deinflectedSuffix: "ない", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "めぇ", deinflectedSuffix: "むい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "みぃ", deinflectedSuffix: "むい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "ちぃ", deinflectedSuffix: "つい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "せぇ", deinflectedSuffix: "すい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "けぇ", deinflectedSuffix: "かい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "げぇ", deinflectedSuffix: "がい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "げぇ", deinflectedSuffix: "ごい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "せぇ", deinflectedSuffix: "さい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "めぇ", deinflectedSuffix: "まい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "ぜぇ", deinflectedSuffix: "ずい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "っぜぇ", deinflectedSuffix: "ずい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "れぇ", deinflectedSuffix: "らい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "でぇ", deinflectedSuffix: "どい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "れぇ", deinflectedSuffix: "れい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "べぇ", deinflectedSuffix: "ばい", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "てぇ", deinflectedSuffix: "たい", conditionsIn: [], conditionsOut: [.adj_i]),
            ]
        )

        dict["n-slang"] = Transform(
            name: "n-slang",
            localization: loc["n-slang"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "んなさい", deinflectedSuffix: "りなさい", conditionsIn: [], conditionsOut: [.nasai]),
                SuffixRule(inflectedSuffix: "らんない", deinflectedSuffix: "られない", conditionsIn: [.adj_i], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "んない", deinflectedSuffix: "らない", conditionsIn: [.adj_i], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "んなきゃ", deinflectedSuffix: "らなきゃ", conditionsIn: [], conditionsOut: [.ya]),
                SuffixRule(inflectedSuffix: "んなきゃ", deinflectedSuffix: "れなきゃ", conditionsIn: [], conditionsOut: [.ya]),
            ]
        )

        dict["imperative negative slang"] = Transform(
            name: "imperative negative slang",
            localization: loc["imperative negative slang"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "んな", deinflectedSuffix: "る", conditionsIn: [], conditionsOut: [.v]),
            ]
        )

        dict["kansai-ben negative"] = Transform(
            name: "kansai-ben negative",
            localization: loc["kansai-ben negative"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "へん", deinflectedSuffix: "ない", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "ひん", deinflectedSuffix: "ない", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "せえへん", deinflectedSuffix: "しない", conditionsIn: [], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "へんかった", deinflectedSuffix: "なかった", conditionsIn: [.ta], conditionsOut: [.ta]),
                SuffixRule(inflectedSuffix: "ひんかった", deinflectedSuffix: "なかった", conditionsIn: [.ta], conditionsOut: [.ta]),
                SuffixRule(inflectedSuffix: "うてへん", deinflectedSuffix: "ってない", conditionsIn: [], conditionsOut: [.adj_i]),
            ]
        )

        dict["kansai-ben -て"] = Transform(
            name: "kansai-ben -て",
            localization: loc["kansai-ben -て"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "うて", deinflectedSuffix: "って", conditionsIn: [.te], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "おうて", deinflectedSuffix: "あって", conditionsIn: [.te], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "こうて", deinflectedSuffix: "かって", conditionsIn: [.te], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "ごうて", deinflectedSuffix: "がって", conditionsIn: [.te], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "そうて", deinflectedSuffix: "さって", conditionsIn: [.te], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "ぞうて", deinflectedSuffix: "ざって", conditionsIn: [.te], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "とうて", deinflectedSuffix: "たって", conditionsIn: [.te], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "どうて", deinflectedSuffix: "だって", conditionsIn: [.te], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "のうて", deinflectedSuffix: "なって", conditionsIn: [.te], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "ほうて", deinflectedSuffix: "はって", conditionsIn: [.te], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "ぼうて", deinflectedSuffix: "ばって", conditionsIn: [.te], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "もうて", deinflectedSuffix: "まって", conditionsIn: [.te], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "ろうて", deinflectedSuffix: "らって", conditionsIn: [.te], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "ようて", deinflectedSuffix: "やって", conditionsIn: [.te], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "ゆうて", deinflectedSuffix: "いって", conditionsIn: [.te], conditionsOut: [.te]),
            ]
        )

        dict["kansai-ben -た"] = Transform(
            name: "kansai-ben -た",
            localization: loc["kansai-ben -た"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "うた", deinflectedSuffix: "った", conditionsIn: [.ta], conditionsOut: [.ta]),
                SuffixRule(inflectedSuffix: "おうた", deinflectedSuffix: "あった", conditionsIn: [.ta], conditionsOut: [.ta]),
                SuffixRule(inflectedSuffix: "こうた", deinflectedSuffix: "かった", conditionsIn: [.ta], conditionsOut: [.ta]),
                SuffixRule(inflectedSuffix: "ごうた", deinflectedSuffix: "がった", conditionsIn: [.ta], conditionsOut: [.ta]),
                SuffixRule(inflectedSuffix: "そうた", deinflectedSuffix: "さった", conditionsIn: [.ta], conditionsOut: [.ta]),
                SuffixRule(inflectedSuffix: "ぞうた", deinflectedSuffix: "ざった", conditionsIn: [.ta], conditionsOut: [.ta]),
                SuffixRule(inflectedSuffix: "とうた", deinflectedSuffix: "たった", conditionsIn: [.ta], conditionsOut: [.ta]),
                SuffixRule(inflectedSuffix: "どうた", deinflectedSuffix: "だった", conditionsIn: [.ta], conditionsOut: [.ta]),
                SuffixRule(inflectedSuffix: "のうた", deinflectedSuffix: "なった", conditionsIn: [.ta], conditionsOut: [.ta]),
                SuffixRule(inflectedSuffix: "ほうた", deinflectedSuffix: "はった", conditionsIn: [.ta], conditionsOut: [.ta]),
                SuffixRule(inflectedSuffix: "ぼうた", deinflectedSuffix: "ばった", conditionsIn: [.ta], conditionsOut: [.ta]),
                SuffixRule(inflectedSuffix: "もうた", deinflectedSuffix: "まった", conditionsIn: [.ta], conditionsOut: [.ta]),
                SuffixRule(inflectedSuffix: "ろうた", deinflectedSuffix: "らった", conditionsIn: [.ta], conditionsOut: [.ta]),
                SuffixRule(inflectedSuffix: "ようた", deinflectedSuffix: "やった", conditionsIn: [.ta], conditionsOut: [.ta]),
                SuffixRule(inflectedSuffix: "ゆうた", deinflectedSuffix: "いった", conditionsIn: [.ta], conditionsOut: [.ta]),
            ]
        )

        dict["kansai-ben -たら"] = Transform(
            name: "kansai-ben -たら",
            localization: loc["kansai-ben -たら"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "うたら", deinflectedSuffix: "ったら", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "おうたら", deinflectedSuffix: "あったら", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "こうたら", deinflectedSuffix: "かったら", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "ごうたら", deinflectedSuffix: "がったら", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "そうたら", deinflectedSuffix: "さったら", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "ぞうたら", deinflectedSuffix: "ざったら", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "とうたら", deinflectedSuffix: "たったら", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "どうたら", deinflectedSuffix: "だったら", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "のうたら", deinflectedSuffix: "なったら", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "ほうたら", deinflectedSuffix: "はったら", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "ぼうたら", deinflectedSuffix: "ばったら", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "もうたら", deinflectedSuffix: "まったら", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "ろうたら", deinflectedSuffix: "らったら", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "ようたら", deinflectedSuffix: "やったら", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "ゆうたら", deinflectedSuffix: "いったら", conditionsIn: [], conditionsOut: []),
            ]
        )

        dict["kansai-ben -たり"] = Transform(
            name: "kansai-ben -たり",
            localization: loc["kansai-ben -たり"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "うたり", deinflectedSuffix: "ったり", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "おうたり", deinflectedSuffix: "あったり", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "こうたり", deinflectedSuffix: "かったり", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "ごうたり", deinflectedSuffix: "がったり", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "そうたり", deinflectedSuffix: "さったり", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "ぞうたり", deinflectedSuffix: "ざったり", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "とうたり", deinflectedSuffix: "たったり", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "どうたり", deinflectedSuffix: "だったり", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "のうたり", deinflectedSuffix: "なったり", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "ほうたり", deinflectedSuffix: "はったり", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "ぼうたり", deinflectedSuffix: "ばったり", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "もうたり", deinflectedSuffix: "まったり", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "ろうたり", deinflectedSuffix: "らったり", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "ようたり", deinflectedSuffix: "やったり", conditionsIn: [], conditionsOut: []),
                SuffixRule(inflectedSuffix: "ゆうたり", deinflectedSuffix: "いったり", conditionsIn: [], conditionsOut: []),
            ]
        )

        dict["kansai-ben -く"] = Transform(
            name: "kansai-ben -く",
            localization: loc["kansai-ben -く"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "う", deinflectedSuffix: "く", conditionsIn: [], conditionsOut: [.ku]),
                SuffixRule(inflectedSuffix: "こう", deinflectedSuffix: "かく", conditionsIn: [], conditionsOut: [.ku]),
                SuffixRule(inflectedSuffix: "ごう", deinflectedSuffix: "がく", conditionsIn: [], conditionsOut: [.ku]),
                SuffixRule(inflectedSuffix: "そう", deinflectedSuffix: "さく", conditionsIn: [], conditionsOut: [.ku]),
                SuffixRule(inflectedSuffix: "とう", deinflectedSuffix: "たく", conditionsIn: [], conditionsOut: [.ku]),
                SuffixRule(inflectedSuffix: "のう", deinflectedSuffix: "なく", conditionsIn: [], conditionsOut: [.ku]),
                SuffixRule(inflectedSuffix: "ぼう", deinflectedSuffix: "ばく", conditionsIn: [], conditionsOut: [.ku]),
                SuffixRule(inflectedSuffix: "もう", deinflectedSuffix: "まく", conditionsIn: [], conditionsOut: [.ku]),
                SuffixRule(inflectedSuffix: "ろう", deinflectedSuffix: "らく", conditionsIn: [], conditionsOut: [.ku]),
                SuffixRule(inflectedSuffix: "よう", deinflectedSuffix: "よく", conditionsIn: [], conditionsOut: [.ku]),
                SuffixRule(inflectedSuffix: "しゅう", deinflectedSuffix: "しく", conditionsIn: [], conditionsOut: [.ku]),
            ]
        )

        dict["kansai-ben adjective -て"] = Transform(
            name: "kansai-ben adjective -て",
            localization: loc["kansai-ben adjective -て"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "うて", deinflectedSuffix: "くて", conditionsIn: [.te], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "こうて", deinflectedSuffix: "かくて", conditionsIn: [.te], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "ごうて", deinflectedSuffix: "がくて", conditionsIn: [.te], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "そうて", deinflectedSuffix: "さくて", conditionsIn: [.te], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "とうて", deinflectedSuffix: "たくて", conditionsIn: [.te], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "のうて", deinflectedSuffix: "なくて", conditionsIn: [.te], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "ぼうて", deinflectedSuffix: "ばくて", conditionsIn: [.te], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "もうて", deinflectedSuffix: "まくて", conditionsIn: [.te], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "ろうて", deinflectedSuffix: "らくて", conditionsIn: [.te], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "ようて", deinflectedSuffix: "よくて", conditionsIn: [.te], conditionsOut: [.te]),
                SuffixRule(inflectedSuffix: "しゅうて", deinflectedSuffix: "しくて", conditionsIn: [.te], conditionsOut: [.te]),
            ]
        )

        dict["kansai-ben adjective negative"] = Transform(
            name: "kansai-ben adjective negative",
            localization: loc["kansai-ben adjective negative"] ?? LocalizedDeinflectionContent(entries: [:]),
            rules: [
                SuffixRule(inflectedSuffix: "うない", deinflectedSuffix: "くない", conditionsIn: [.adj_i], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "こうない", deinflectedSuffix: "かくない", conditionsIn: [.adj_i], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "ごうない", deinflectedSuffix: "がくない", conditionsIn: [.adj_i], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "そうない", deinflectedSuffix: "さくない", conditionsIn: [.adj_i], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "とうない", deinflectedSuffix: "たくない", conditionsIn: [.adj_i], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "のうない", deinflectedSuffix: "なくない", conditionsIn: [.adj_i], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "ぼうない", deinflectedSuffix: "ばくない", conditionsIn: [.adj_i], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "もうない", deinflectedSuffix: "まくない", conditionsIn: [.adj_i], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "ろうない", deinflectedSuffix: "らくない", conditionsIn: [.adj_i], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "ようない", deinflectedSuffix: "よくない", conditionsIn: [.adj_i], conditionsOut: [.adj_i]),
                SuffixRule(inflectedSuffix: "しゅうない", deinflectedSuffix: "しくない", conditionsIn: [.adj_i], conditionsOut: [.adj_i]),
            ]
        )

        return dict
    }()
}
