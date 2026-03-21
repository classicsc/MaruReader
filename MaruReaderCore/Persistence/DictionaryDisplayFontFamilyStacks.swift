// DictionaryDisplayFontFamilyStacks.swift
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

public enum DictionaryDisplayFontFamilyStacks {
    public static let legacySystem = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif"
    public static let sansSerif = "Hiragino Sans, HelveticaNeue, Helvetica, Arial, sans-serif"
    public static let serif = "Hiragino Mincho ProN, TimesNewRomanPSMT, 'Times New Roman', Times, Georgia, serif"
    public static let monospace = "'Osaka Mono', Menlo, Monaco, 'Courier New', monospace"

    public static func normalize(_ fontFamily: String) -> String {
        switch fontFamily {
        case legacySystem:
            sansSerif
        default:
            fontFamily
        }
    }
}
