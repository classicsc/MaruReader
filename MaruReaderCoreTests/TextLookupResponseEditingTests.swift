// TextLookupResponseEditingTests.swift
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
@testable import MaruReaderCore
import Testing

struct TextLookupResponseEditingTests {
    // MARK: - Test Helpers

    private func makeTestStyles() -> DisplayStyles {
        DisplayStyles(
            fontFamily: "Test",
            contentFontSize: 1.0,
            popupFontSize: 1.0,
            showDeinflection: true,
            deinflectionDescriptionLanguage: "system",
            pitchDownstepNotationInHeaderEnabled: false,
            pitchResultsAreaCollapsedDisplay: false,
            pitchResultsAreaDownstepNotationEnabled: false,
            pitchResultsAreaDownstepPositionEnabled: false,
            pitchResultsAreaEnabled: false
        )
    }

    private func makeTestGroupedResults(expression: String, reading: String? = nil) -> GroupedSearchResults {
        GroupedSearchResults(
            termKey: expression,
            expression: expression,
            reading: reading,
            dictionariesResults: [],
            pitchAccentResults: [],
            termTags: [],
            deinflectionInfo: nil
        )
    }

    private func makeTestResponse(context: String, primaryResult: String, resultStartOffset: Int) -> TextLookupResponse {
        let request = TextLookupRequest(context: context, offset: resultStartOffset)
        let startIndex = context.index(context.startIndex, offsetBy: resultStartOffset)
        let endIndex = context.index(startIndex, offsetBy: primaryResult.count)
        let range = startIndex ..< endIndex

        return TextLookupResponse(
            request: request,
            results: [makeTestGroupedResults(expression: primaryResult)],
            primaryResult: primaryResult,
            primaryResultSourceRange: range,
            styles: makeTestStyles()
        )
    }

    // MARK: - updateEditedRange Tests

    @Test func updateEditedRange_singleOccurrence_findsTermAndUpdatesRange() {
        // Arrange: "私は日本語を勉強しています" with "日本語" matched
        var response = makeTestResponse(
            context: "私は日本語を勉強しています",
            primaryResult: "日本語",
            resultStartOffset: 2
        )

        // Act: Edit context to add prefix
        let found = response.updateEditedRange(for: "昨日、私は日本語を勉強しています")

        // Assert
        #expect(found == true)
        #expect(response.editedContext == "昨日、私は日本語を勉強しています")
        #expect(response.editedPrimaryResultSourceRange != nil)

        // Verify the range points to the correct location in edited context
        if let range = response.editedPrimaryResultSourceRange {
            let matchedText = String(response.effectiveContext[range])
            #expect(matchedText == "日本語")
        }
    }

    @Test func updateEditedRange_termRemoved_returnsFalseAndClearsRange() {
        // Arrange
        var response = makeTestResponse(
            context: "私は日本語を勉強しています",
            primaryResult: "日本語",
            resultStartOffset: 2
        )

        // Act: Edit context to remove the term
        let found = response.updateEditedRange(for: "私は英語を勉強しています")

        // Assert
        #expect(found == false)
        #expect(response.editedContext == "私は英語を勉強しています")
        #expect(response.editedPrimaryResultSourceRange == nil)
    }

    @Test func updateEditedRange_emptyContext_returnsFalse() {
        // Arrange
        var response = makeTestResponse(
            context: "日本語",
            primaryResult: "日本語",
            resultStartOffset: 0
        )

        // Act
        let found = response.updateEditedRange(for: "")

        // Assert
        #expect(found == false)
        #expect(response.editedPrimaryResultSourceRange == nil)
    }

    @Test func updateEditedRange_multipleOccurrences_selectsClosestToOriginalPosition() {
        // Arrange: "日本語は日本語です" with first "日本語" (position 0)
        var response = makeTestResponse(
            context: "日本語は日本語です",
            primaryResult: "日本語",
            resultStartOffset: 0
        )

        // Act: Edit to add prefix, both occurrences are still present
        // Original was at position 0 (proportion 0), so should pick first occurrence
        let found = response.updateEditedRange(for: "私の日本語は日本語です")

        // Assert
        #expect(found == true)
        if let range = response.editedPrimaryResultSourceRange {
            let startOffset = response.effectiveContext.distance(
                from: response.effectiveContext.startIndex,
                to: range.lowerBound
            )
            // Should select the first occurrence (closer to original position 0)
            #expect(startOffset == 2) // "私の" is 2 characters
        }
    }

    @Test func updateEditedRange_multipleOccurrences_selectsSecondWhenOriginalWasLater() {
        // Arrange: "あああ日本語いいい日本語ううう" with second "日本語" (position 9)
        // Context is 15 chars, second occurrence at position 9 (proportion ~60%)
        let context = "あああ日本語いいい日本語ううう"
        var response = makeTestResponse(
            context: context,
            primaryResult: "日本語",
            resultStartOffset: 9
        )

        // Act: Edit to add prefix "XX" (2 chars), making total 17 chars
        // Original proportion was 9/15 = 60%, target = 60% of 17 = 10.2 ≈ 10
        // First "日本語" in edited context: position 5 (distance from 10 = 5)
        // Second "日本語" in edited context: position 11 (distance from 10 = 1)
        // Should select second occurrence
        let found = response.updateEditedRange(for: "XXあああ日本語いいい日本語ううう")

        // Assert
        #expect(found == true)
        if let range = response.editedPrimaryResultSourceRange {
            let startOffset = response.effectiveContext.distance(
                from: response.effectiveContext.startIndex,
                to: range.lowerBound
            )
            // Should select the second occurrence (position 11, closer to target 10)
            #expect(startOffset == 11)
        }
    }

    @Test func updateEditedRange_termAtStart_worksCorrectly() {
        // Arrange
        var response = makeTestResponse(
            context: "日本語を勉強する",
            primaryResult: "日本語",
            resultStartOffset: 0
        )

        // Act
        let found = response.updateEditedRange(for: "日本語は難しい")

        // Assert
        #expect(found == true)
        if let range = response.editedPrimaryResultSourceRange {
            let startOffset = response.effectiveContext.distance(
                from: response.effectiveContext.startIndex,
                to: range.lowerBound
            )
            #expect(startOffset == 0)
        }
    }

    @Test func updateEditedRange_termAtEnd_worksCorrectly() {
        // Arrange: "勉強する日本語" with "日本語" at the end
        var response = makeTestResponse(
            context: "勉強する日本語",
            primaryResult: "日本語",
            resultStartOffset: 4
        )

        // Act
        let found = response.updateEditedRange(for: "私が好きな日本語")

        // Assert
        #expect(found == true)
        if let range = response.editedPrimaryResultSourceRange {
            let matchedText = String(response.effectiveContext[range])
            #expect(matchedText == "日本語")
            // Verify it's at the end
            #expect(range.upperBound == response.effectiveContext.endIndex)
        }
    }

    // MARK: - Effective Offset Tests

    @Test func effectiveMatchStartInContext_returnsOriginalOffsetWhenNotEdited() {
        // Arrange
        let response = makeTestResponse(
            context: "私は日本語を勉強しています",
            primaryResult: "日本語",
            resultStartOffset: 2
        )

        // Act & Assert
        #expect(response.effectiveMatchStartInContext == 2)
    }

    @Test func effectiveMatchStartInContext_returnsUpdatedOffsetAfterEdit() {
        // Arrange
        var response = makeTestResponse(
            context: "私は日本語を勉強しています",
            primaryResult: "日本語",
            resultStartOffset: 2
        )

        // Act
        _ = response.updateEditedRange(for: "昨日、私は日本語を勉強しています")

        // Assert - "昨日、私は" is 5 characters, so offset should be 5
        #expect(response.effectiveMatchStartInContext == 5)
    }

    @Test func effectiveMatchEndInContext_returnsCorrectValue() {
        // Arrange
        var response = makeTestResponse(
            context: "日本語",
            primaryResult: "日本語",
            resultStartOffset: 0
        )

        // Act
        _ = response.updateEditedRange(for: "私の日本語")

        // Assert
        #expect(response.effectiveMatchStartInContext == 2)
        #expect(response.effectiveMatchEndInContext == 5) // 2 + 3 characters
    }

    @Test func effectiveMatchStartInContext_returnsNilWhenTermRemoved() {
        // Arrange
        var response = makeTestResponse(
            context: "日本語",
            primaryResult: "日本語",
            resultStartOffset: 0
        )

        // Act
        _ = response.updateEditedRange(for: "英語")

        // Assert
        #expect(response.effectiveMatchStartInContext == nil)
        #expect(response.effectiveMatchEndInContext == nil)
    }

    // MARK: - effectiveContext and effectivePrimaryResultSourceRange Tests

    @Test func effectiveContext_returnsOriginalWhenNotEdited() {
        // Arrange
        let response = makeTestResponse(
            context: "日本語",
            primaryResult: "日本語",
            resultStartOffset: 0
        )

        // Assert
        #expect(response.effectiveContext == "日本語")
    }

    @Test func effectiveContext_returnsEditedWhenSet() {
        // Arrange
        var response = makeTestResponse(
            context: "日本語",
            primaryResult: "日本語",
            resultStartOffset: 0
        )

        // Act
        _ = response.updateEditedRange(for: "私の日本語")

        // Assert
        #expect(response.effectiveContext == "私の日本語")
    }

    @Test func effectivePrimaryResultSourceRange_returnsOriginalWhenNotEdited() {
        // Arrange
        let response = makeTestResponse(
            context: "日本語",
            primaryResult: "日本語",
            resultStartOffset: 0
        )

        // Assert
        #expect(response.effectivePrimaryResultSourceRange == response.primaryResultSourceRange)
    }

    @Test func effectivePrimaryResultSourceRange_returnsEditedWhenSet() {
        // Arrange
        var response = makeTestResponse(
            context: "日本語",
            primaryResult: "日本語",
            resultStartOffset: 0
        )

        // Act
        _ = response.updateEditedRange(for: "私の日本語")

        // Assert
        #expect(response.effectivePrimaryResultSourceRange == response.editedPrimaryResultSourceRange)
        #expect(response.effectivePrimaryResultSourceRange != response.primaryResultSourceRange)
    }
}
