// ReadiumLocatorFixtures.swift
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

import ReadiumShared

/// Stored Readium 3.x locator shape, deliberately formatted independently of the current encoder.
enum ReadiumLocatorFixtures {
    static let savedJSON = #"""
    {
      "text": {"highlight": "星", "before": "夜の", "after": "たち"},
      "title": "第一章",
      "type": "application/xhtml+xml",
      "href": "OEBPS/Text/chapter-1.xhtml",
      "locations": {
        "position": 7, "progression": 0.25, "totalProgression": 0.42,
        "fragments": ["paragraph-3"], "cssSelector": "#paragraph-3"
      }
    }
    """#

    static var locator: Locator {
        Locator(
            href: AnyURL(path: "OEBPS/Text/chapter-1.xhtml")!,
            mediaType: .xhtml,
            title: "第一章",
            locations: .init(
                fragments: ["paragraph-3"],
                progression: 0.25,
                totalProgression: 0.42,
                position: 7,
                otherLocations: ["cssSelector": "#paragraph-3"]
            ),
            text: .init(after: "たち", before: "夜の", highlight: "星")
        )
    }
}
