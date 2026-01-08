// BundleFinder.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import Foundation

private class BundleFinder {}

public extension Bundle {
    static let framework: Bundle = {
        let bundle = Bundle(for: BundleFinder.self)
        let bundleName = "MaruResources"
        let url = bundle.resourceURL?.appendingPathComponent(bundleName + ".bundle")
        return url.flatMap(Bundle.init(url:)) ?? bundle
    }()
}
