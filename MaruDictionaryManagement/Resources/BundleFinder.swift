// BundleFinder.swift
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

private final class BundleFinder {}

extension Bundle {
    static let managementFramework: Bundle = {
        let bundle = Bundle(for: BundleFinder.self)
        let candidateNames = [
            "MaruDictionaryManagement_MaruDictionaryManagement",
            "MaruDictionaryManagement",
        ]

        for candidate in candidateNames {
            if let url = bundle.resourceURL?.appendingPathComponent(candidate + ".bundle"),
               let resourceBundle = Bundle(url: url)
            {
                return resourceBundle
            }
        }

        return bundle
    }()
}
