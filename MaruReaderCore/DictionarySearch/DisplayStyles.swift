// DisplayStyles.swift
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

import Foundation

public struct DisplayStyles: Sendable, Codable {
    public let fontFamily: String
    public let contentFontSize: Double
    public let popupFontSize: Double
    public let showDeinflection: Bool
    public let pitchDownstepNotationInHeaderEnabled: Bool
    public let pitchResultsAreaCollapsedDisplay: Bool
    public let pitchResultsAreaDownstepNotationEnabled: Bool
    public let pitchResultsAreaDownstepPositionEnabled: Bool
    public let pitchResultsAreaEnabled: Bool

    public init(
        fontFamily: String,
        contentFontSize: Double,
        popupFontSize: Double,
        showDeinflection: Bool,
        pitchDownstepNotationInHeaderEnabled: Bool,
        pitchResultsAreaCollapsedDisplay: Bool,
        pitchResultsAreaDownstepNotationEnabled: Bool,
        pitchResultsAreaDownstepPositionEnabled: Bool,
        pitchResultsAreaEnabled: Bool
    ) {
        self.fontFamily = fontFamily
        self.contentFontSize = contentFontSize
        self.popupFontSize = popupFontSize
        self.showDeinflection = showDeinflection
        self.pitchDownstepNotationInHeaderEnabled = pitchDownstepNotationInHeaderEnabled
        self.pitchResultsAreaCollapsedDisplay = pitchResultsAreaCollapsedDisplay
        self.pitchResultsAreaDownstepNotationEnabled = pitchResultsAreaDownstepNotationEnabled
        self.pitchResultsAreaDownstepPositionEnabled = pitchResultsAreaDownstepPositionEnabled
        self.pitchResultsAreaEnabled = pitchResultsAreaEnabled
    }
}
