// UIView+Descendants.swift
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

import UIKit

extension UIView {
    func descendants<T: UIView>(ofType type: T.Type) -> [T] {
        var results: [T] = []

        if let view = self as? T {
            results.append(view)
        }

        for subview in subviews {
            results.append(contentsOf: subview.descendants(ofType: type))
        }

        return results
    }
}
