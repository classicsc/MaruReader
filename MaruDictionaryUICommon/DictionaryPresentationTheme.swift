// DictionaryPresentationTheme.swift
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

import MaruReaderCore
import SwiftUI

public struct DictionaryPresentationTheme: Sendable {
    public let preferredColorScheme: ColorScheme?
    public let backgroundColor: Color
    public let foregroundColor: Color
    public let secondaryForegroundColor: Color
    public let separatorColor: Color
    public let dictionaryWebTheme: DictionaryWebTheme?

    public init(
        preferredColorScheme: ColorScheme? = nil,
        backgroundColor: Color,
        foregroundColor: Color,
        secondaryForegroundColor: Color,
        separatorColor: Color,
        dictionaryWebTheme: DictionaryWebTheme? = nil
    ) {
        self.preferredColorScheme = preferredColorScheme
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.secondaryForegroundColor = secondaryForegroundColor
        self.separatorColor = separatorColor
        self.dictionaryWebTheme = dictionaryWebTheme
    }
}

public extension EnvironmentValues {
    @Entry var dictionaryPresentationTheme: DictionaryPresentationTheme?
}
