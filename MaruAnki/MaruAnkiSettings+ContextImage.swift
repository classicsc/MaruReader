// MaruAnkiSettings+ContextImage.swift
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
import Foundation

public extension MaruAnkiSettings {
    /// Decodes the context image configuration from the stored JSON string.
    ///
    /// Returns the default configuration if the stored value is nil or invalid.
    var decodedContextImageConfiguration: ContextImageConfiguration {
        get {
            guard let jsonString = contextImageConfiguration,
                  let data = jsonString.data(using: .utf8)
            else {
                return .default
            }

            do {
                return try JSONDecoder().decode(ContextImageConfiguration.self, from: data)
            } catch {
                return .default
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                contextImageConfiguration = String(data: data, encoding: .utf8)
            } catch {
                contextImageConfiguration = nil
            }
        }
    }
}
