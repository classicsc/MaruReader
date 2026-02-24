// DeinflectionLocalizationTests.swift
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

@testable import MaruReaderCore
import Testing

struct DeinflectionLocalizationTests {
    // MARK: - JSON Loading

    @MainActor @Test func localizationsLoadSuccessfully() {
        let localizations = loadDeinflectionLocalizations()
        #expect(!localizations.isEmpty, "Localizations should not be empty")
        #expect(localizations.count == 53, "Should have 53 transform localizations, got \(localizations.count)")
    }

    @MainActor @Test func allTransformsHaveLocalizations() {
        let transforms = JapaneseDeinflector.transforms
        let localizations = JapaneseDeinflector.localizations

        for (name, _) in transforms {
            #expect(localizations[name] != nil, "Transform '\(name)' should have a localization entry")
        }
    }

    @MainActor @Test func allLanguagesPopulated() {
        let localizations = loadDeinflectionLocalizations()
        let languages = ["en", "ja", "zh-Hant", "zh-Hans"]

        for (key, content) in localizations {
            for lang in languages {
                let displayName = content.displayName(for: DeinflectionLanguage(rawValue: lang) ?? .en)
                #expect(!displayName.isEmpty, "Transform '\(key)' should have a non-empty displayName for \(lang)")
            }
        }
    }

    // MARK: - LocalizedDeinflectionContent Resolution

    @Test func displayNameResolvesCorrectLanguage() {
        let content = LocalizedDeinflectionContent(entries: [
            "en": LocalizedDeinflectionEntry(displayName: "causative", description: "English desc"),
            "ja": LocalizedDeinflectionEntry(displayName: "～せる・させる", description: "日本語の説明"),
            "zh-Hant": LocalizedDeinflectionEntry(displayName: "使役形", description: "繁中說明"),
            "zh-Hans": LocalizedDeinflectionEntry(displayName: "使役形", description: "简中说明"),
        ])

        #expect(content.displayName(for: .en) == "causative")
        #expect(content.displayName(for: .ja) == "～せる・させる")
        #expect(content.displayName(for: .zhHant) == "使役形")
        #expect(content.displayName(for: .zhHans) == "使役形")
    }

    @Test func descriptionResolvesCorrectLanguage() {
        let content = LocalizedDeinflectionContent(entries: [
            "en": LocalizedDeinflectionEntry(displayName: "test", description: "English desc"),
            "ja": LocalizedDeinflectionEntry(displayName: "テスト", description: "日本語の説明"),
        ])

        #expect(content.description(for: .en) == "English desc")
        #expect(content.description(for: .ja) == "日本語の説明")
    }

    @Test func fallsBackToEnglishForMissingLanguage() {
        let content = LocalizedDeinflectionContent(entries: [
            "en": LocalizedDeinflectionEntry(displayName: "English", description: "English desc"),
        ])

        #expect(content.displayName(for: .ja) == "English")
        #expect(content.description(for: .zhHant) == "English desc")
    }

    @Test func emptyContentReturnsEmptyString() {
        let content = LocalizedDeinflectionContent(entries: [:])
        #expect(content.displayName(for: .en) == "")
        #expect(content.description(for: .ja) == "")
    }

    // MARK: - DeinflectionLanguage

    @Test func languageJsonKeys() {
        #expect(DeinflectionLanguage.en.jsonKey == "en")
        #expect(DeinflectionLanguage.ja.jsonKey == "ja")
        #expect(DeinflectionLanguage.zhHant.jsonKey == "zh-Hant")
        #expect(DeinflectionLanguage.zhHans.jsonKey == "zh-Hans")
    }

    @Test func languageRawValues() {
        #expect(DeinflectionLanguage(rawValue: "system") == .followSystem)
        #expect(DeinflectionLanguage(rawValue: "en") == .en)
        #expect(DeinflectionLanguage(rawValue: "ja") == .ja)
        #expect(DeinflectionLanguage(rawValue: "zh-Hant") == .zhHant)
        #expect(DeinflectionLanguage(rawValue: "zh-Hans") == .zhHans)
        #expect(DeinflectionLanguage(rawValue: "invalid") == nil)
    }

    // MARK: - Condition DisplayName

    @Test func conditionDisplayNameLocalized() {
        let condition = Condition.v1
        #expect(condition.displayName(for: .en) == "Ichidan verb")
        #expect(condition.displayName(for: .ja) == "一段動詞")
        #expect(condition.displayName(for: .zhHant) == "一段動詞")
        #expect(condition.displayName(for: .zhHans) == "一段动词")
    }

    // MARK: - Transform Localization via Pipeline

    @MainActor @Test func transformLocalizationResolves() {
        let transform = JapaneseDeinflector.transforms["causative"]
        #expect(transform != nil)
        #expect(transform?.localization.displayName(for: .en) == "causative")
        #expect(transform?.localization.displayName(for: .ja) == "～せる・させる")
    }
}
