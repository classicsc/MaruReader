// AnkiNoteDraftTests.swift
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
@testable import MaruAnki
import Testing

struct AnkiNoteDraftTests {
    private struct StubResolver: TemplateValueResolver {
        func resolve(_ templateValue: TemplateValue) async -> TemplateResolvedValue {
            switch templateValue {
            case .expression: .text("食べる")
            case .reading: .text("たべる")
            case .singlePitchAccent: .text("2")
            case .pitchAccentList: .text("2, 0")
            case let .customHTMLValue(value): .text(value)
            case .pronunciationAudio: .media(["audio": URL(string: "https://example.com/a.mp3")!])
            default: .empty
            }
        }
    }

    private let fieldMap = AnkiFieldMap(map: [
        "Sentence": [.clozePrefix, .customHTMLValue(value: "<b>"), .clozeBody],
        "Expression": [.expression],
        "Pitch": [.singlePitchAccent],
        "Audio": [.pronunciationAudio],
    ])

    @Test func resolveKeepsValueOrderAndSortsFieldsByName() async {
        let draft = await AnkiNoteDraft.resolve(fieldMap: fieldMap, resolver: StubResolver())

        #expect(draft.fields.map(\.name) == ["Audio", "Expression", "Pitch", "Sentence"])
        #expect(draft.field(named: "Sentence")?.values.map(\.template) == [.clozePrefix, .customHTMLValue(value: "<b>"), .clozeBody])
        #expect(draft.field(named: "Expression")?.values.first?.resolved.text == "食べる")
        #expect(draft.fields.allSatisfy { !$0.isEdited })
        #expect(draft.resolvedFields["Sentence"]?.map(\.text) == [nil, "<b>", nil])
        #expect(draft.resolvedFields["Audio"]?.first?.mediaFiles.count == 1)
    }

    @Test func editsAreTrackedAndRestored() async throws {
        var draft = await AnkiNoteDraft.resolve(fieldMap: fieldMap, resolver: StubResolver())
        let valueID = try #require(draft.field(named: "Sentence")?.values[1].id)

        draft.update(field: "Sentence") { $0.values.removeLast() }
        draft.update(field: "Sentence", value: valueID) { $0.resolved = .text("<i>") }

        #expect(draft.field(named: "Sentence")?.isEdited == true)
        #expect(draft.field(named: "Expression")?.isEdited == false)
        #expect(draft.resolvedFields["Sentence"]?.map(\.text) == [nil, "<i>"])

        draft.update(field: "Sentence") { $0.restore() }

        #expect(draft.field(named: "Sentence")?.isEdited == false)
        #expect(draft.resolvedFields["Sentence"]?.map(\.text) == [nil, "<b>", nil])
    }

    @Test func previewHTMLInlinesImagesAndLeavesOutMediaOnlyValues() throws {
        let image = try #require(URL(string: "https://example.com/p.png"))
        let glossary = TemplateResolvedValue(text: "<img src=\"p.png\"> gloss", mediaFiles: ["p.png": image])
        let field = AnkiNoteDraftField(name: "Glossary", values: [
            AnkiNoteDraftValue(template: .singleGlossary, resolved: glossary),
            AnkiNoteDraftValue(template: .pronunciationAudio, resolved: .media(["audio": image])),
        ])

        #expect(field.previewHTML == "<img src=\"https://example.com/p.png\"> gloss")
        #expect(TemplateResolvedValue.media(["audio": image]).previewHTML.isEmpty)
    }

    @Test func clearingPitchAccentEmptiesOnlyPitchValues() async {
        var draft = await AnkiNoteDraft.resolve(fieldMap: fieldMap, resolver: StubResolver())

        draft.clearPitchAccentValues()

        #expect(draft.field(named: "Pitch")?.values.first?.resolved == .empty)
        #expect(draft.field(named: "Pitch")?.isEdited == true)
        #expect(draft.field(named: "Expression")?.values.first?.resolved.text == "食べる")
    }
}
