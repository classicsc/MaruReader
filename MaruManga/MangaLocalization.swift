// MangaLocalization.swift
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

private final class MangaLocalizationBundleToken {}

enum MangaLocalization {
    private static let bundle = Bundle(for: MangaLocalizationBundleToken.self)

    static func string(
        _ keyAndValue: String.LocalizationValue,
        locale: Locale = .current,
        comment: StaticString? = nil
    ) -> String {
        String(localized: keyAndValue, bundle: bundle, locale: locale, comment: comment)
    }

    static func readerContextInfo(title: String?, pageNumber: Int) -> String {
        string("\(fallbackTitle(title, emptyFallback: "Manga")) - Page \(pageNumber)")
    }

    static func deleteConfirmationMessage(title: String?) -> String {
        string("Are you sure you want to delete \"\(fallbackTitle(title, emptyFallback: "Unknown Manga"))\"? This action cannot be undone.")
    }

    private static func fallbackTitle(_ title: String?, emptyFallback: String.LocalizationValue) -> String {
        guard let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return string(emptyFallback)
        }

        return trimmed
    }
}
