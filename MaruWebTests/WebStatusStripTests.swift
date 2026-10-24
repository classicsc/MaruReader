// WebStatusStripTests.swift
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

@testable import MaruWeb
import SwiftUI
import Testing

struct WebStatusStripTests {
    @Test func oneSidedInsetIsAStrip() {
        let trailing = WebStatusStrip(safeAreaInsets: EdgeInsets(top: 0, leading: 0, bottom: 34, trailing: 84))
        #expect(trailing == WebStatusStrip(edge: .trailing, width: 84))
        let leading = WebStatusStrip(safeAreaInsets: EdgeInsets(top: 0, leading: 84, bottom: 34, trailing: 0))
        #expect(leading == WebStatusStrip(edge: .leading, width: 84))
    }

    @Test func symmetricOrMissingInsetsAreNot() {
        #expect(WebStatusStrip(safeAreaInsets: EdgeInsets(top: 0, leading: 59, bottom: 21, trailing: 59)) == nil)
        #expect(WebStatusStrip(safeAreaInsets: EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0)) == nil)
    }
}
