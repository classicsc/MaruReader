// BookReaderBookmarkRowData.swift
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

import CoreData
import ReadiumShared

struct BookReaderBookmarkRowData: Identifiable, Equatable {
    let snapshot: BookReaderBookmarkSnapshot
    let displayTitle: String
    let chapterTitle: String?
    let progressText: String?
    let isCurrent: Bool

    var id: NSManagedObjectID {
        snapshot.id
    }

    static func makeRows(
        bookmarks: [BookReaderBookmarkSnapshot],
        currentHref: String?,
        chapterTitleByHref: [String: String]
    ) -> [Self] {
        bookmarks.map { bookmark in
            let href = bookmark.locator?.href.string

            return Self(
                snapshot: bookmark,
                displayTitle: bookmark.title ?? String(localized: "Bookmark"),
                chapterTitle: href.flatMap { chapterTitleByHref[$0] },
                progressText: bookmark.locator.flatMap(progressText(for:)),
                isCurrent: href == currentHref
            )
        }
    }

    private static func progressText(for locator: Locator) -> String? {
        if let totalProgression = locator.locations.totalProgression {
            let percent = Int(totalProgression * 100)
            return String(localized: "Book \(percent)%")
        }
        if let position = locator.locations.position {
            return String(localized: "Position \(position)")
        }
        return nil
    }
}
