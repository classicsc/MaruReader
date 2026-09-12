// Locator+Storage.swift
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
import ReadiumShared

extension Locator {
    func storageJSON() throws -> String {
        // Foundation raises an Objective-C exception for nonfinite numbers,
        // which Readium's throwing serializer cannot catch.
        guard JSONSerialization.isValidJSONObject(jsonValue.any) else {
            throw JSONError.serializing(Locator.self, cause: nil)
        }
        return try jsonString()
    }
}
