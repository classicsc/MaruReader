// FrequencyInfo.swift
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

public struct FrequencyInfo: Sendable {
    public let dictionaryID: UUID
    public let dictionaryTitle: String
    public let value: Double
    public let displayValue: String?
    public let mode: String?
    public let priority: Int

    /// The string to display for this frequency.
    /// Uses `displayValue` if available, otherwise formats `value` as an integer.
    public var displayString: String {
        displayValue ?? String(Int(round(value)))
    }
}
