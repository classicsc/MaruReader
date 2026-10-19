// AnkiLocalization.swift
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

private final class AnkiLocalizationBundleToken {}

enum AnkiLocalization {
    private static let bundle = Bundle(for: AnkiLocalizationBundleToken.self)

    static func string(_ keyAndValue: String.LocalizationValue, comment: StaticString? = nil) -> String {
        String(localized: keyAndValue, bundle: bundle, comment: comment)
    }
}
