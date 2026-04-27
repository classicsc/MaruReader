// WebFilterListSeed.swift
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

/// A description of a filter list to insert into storage. Used by both the first-launch
/// seeder and the "Add Filter List" UI flow.
public struct WebFilterListSeed: Sendable, Hashable {
    public let name: String
    public let sourceURL: URL
    public let format: WebFilterListFormat

    public init(name: String, sourceURL: URL, format: WebFilterListFormat) {
        self.name = name
        self.sourceURL = sourceURL
        self.format = format
    }
}
