// DictionaryDisplayDefaults.swift
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

public enum DictionaryDisplayDefaults {
    public static let defaultFontFamily: String = DictionaryDisplayFontFamilyStacks.sansSerif
    public static let defaultFontSize: Double = 1.0
    public static let defaultPopupFontSize: Double = 1.0
    public static let defaultShowDeinflection: Bool = true
    public static let defaultDeinflectionDescriptionLanguage: String = DeinflectionLanguage.followSystem.rawValue
    public static let defaultPitchDownstepNotationInHeaderEnabled: Bool = true
    public static let defaultPitchResultsAreaCollapsedDisplay: Bool = false
    public static let defaultPitchResultsAreaDownstepNotationEnabled: Bool = false
    public static let defaultPitchResultsAreaDownstepPositionEnabled: Bool = true
    public static let defaultPitchResultsAreaEnabled: Bool = false

    // Context display settings
    public static let defaultContextFontSize: Double = 1.0
    public static let defaultContextFuriganaEnabled: Bool = true
}
