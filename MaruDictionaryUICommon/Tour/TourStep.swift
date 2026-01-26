// TourStep.swift
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

import SwiftUI

/// A single step in a guided tour.
public struct TourStep: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let popoverEdge: Edge

    public init(
        id: String,
        title: String,
        description: String,
        popoverEdge: Edge = .bottom
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.popoverEdge = popoverEdge
    }
}

/// Protocol for defining a tour with its steps and persistence key.
public protocol TourDefinition {
    /// Unique identifier for this tour, used for persistence.
    static var tourID: String { get }

    /// The ordered steps that make up this tour.
    static var steps: [TourStep] { get }
}

/// Preference key for collecting tour anchor bounds from the view hierarchy.
public struct TourAnchorPreferenceKey: PreferenceKey {
    public static let defaultValue: [String: Anchor<CGRect>] = [:]

    public static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

public extension View {
    /// Marks this view as a tour anchor point that can be highlighted during a tour.
    func tourAnchor(_ id: String) -> some View {
        anchorPreference(key: TourAnchorPreferenceKey.self, value: .bounds) { anchor in
            [id: anchor]
        }
    }
}
