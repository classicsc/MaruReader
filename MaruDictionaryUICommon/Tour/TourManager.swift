// TourManager.swift
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
import SwiftUI

/// Manages the state and persistence of guided tours.
@MainActor
@Observable
public final class TourManager {
    private static let tourKeyPrefix = "tour."
    private static let completedSuffix = ".completed"

    public private(set) var isActive: Bool = false
    public private(set) var currentStepIndex: Int = 0
    public private(set) var currentTourSteps: [TourStep] = []

    private var currentTourID: String?

    public init() {}

    /// The current step being displayed, if any.
    public var currentStep: TourStep? {
        guard isActive, currentStepIndex < currentTourSteps.count else { return nil }
        return currentTourSteps[currentStepIndex]
    }

    /// Starts a tour if it hasn't been completed yet.
    /// - Parameter tour: The tour definition to start.
    /// - Returns: `true` if the tour was started, `false` if already completed.
    @discardableResult
    public func startIfNeeded(_ tour: (some TourDefinition).Type) -> Bool {
        guard !isCompleted(tour) else { return false }
        start(tour)
        return true
    }

    /// Starts a tour regardless of completion state.
    public func start<T: TourDefinition>(_: T.Type) {
        currentTourID = T.tourID
        currentTourSteps = T.steps
        currentStepIndex = 0
        isActive = true
    }

    /// Advances to the next step, or completes the tour if on the last step.
    public func next() {
        guard isActive else { return }

        if currentStepIndex < currentTourSteps.count - 1 {
            currentStepIndex += 1
        } else {
            complete()
        }
    }

    /// Skips the current tour and marks it as completed.
    public func skip() {
        complete()
    }

    /// Checks if a tour has been completed.
    public func isCompleted<T: TourDefinition>(_: T.Type) -> Bool {
        UserDefaults.standard.object(forKey: Self.completionKey(for: T.tourID)) != nil
    }

    /// Resets all tour completion states.
    public static func resetAllTours() {
        let defaults = UserDefaults.standard
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys where key.hasPrefix(tourKeyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    /// Resets a specific tour's completion state.
    public static func resetTour<T: TourDefinition>(_: T.Type) {
        UserDefaults.standard.removeObject(forKey: completionKey(for: T.tourID))
    }

    private func complete() {
        guard let tourID = currentTourID else { return }

        UserDefaults.standard.set(Date(), forKey: Self.completionKey(for: tourID))

        isActive = false
        currentStepIndex = 0
        currentTourSteps = []
        currentTourID = nil
    }

    private static func completionKey(for tourID: String) -> String {
        "\(tourKeyPrefix)\(tourID)\(completedSuffix)"
    }
}
