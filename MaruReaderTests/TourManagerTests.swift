// TourManagerTests.swift
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
@testable import MaruDictionaryUICommon
import SwiftUI
import Testing

/// Mock tour definition for testing
enum MockTour: TourDefinition {
    static let tourID = "mock.tour"
    static let steps: [TourStep] = [
        TourStep(id: "step1", title: "Step 1", description: "First step"),
        TourStep(id: "step2", title: "Step 2", description: "Second step"),
        TourStep(id: "step3", title: "Step 3", description: "Third step"),
    ]
}

/// Another mock tour for testing multiple tours
enum AnotherMockTour: TourDefinition {
    static let tourID = "another.mock.tour"
    static let steps: [TourStep] = [
        TourStep(id: "stepA", title: "Step A", description: "First step of another tour"),
    ]
}

@MainActor
struct TourManagerTests {
    init() {
        TourManager.resetAllTours()
    }

    @Test func startTourSetsActiveState() {
        let manager = TourManager()

        manager.start(MockTour.self)

        #expect(manager.isActive)
        #expect(manager.currentStepIndex == 0)
        #expect(manager.currentTourSteps.count == 3)
    }

    @Test func currentStepReturnsCorrectStep() {
        let manager = TourManager()
        manager.start(MockTour.self)

        let currentStep = manager.currentStep
        #expect(currentStep?.id == "step1")
        #expect(currentStep?.title == "Step 1")
    }

    @Test func nextAdvancesToNextStep() {
        let manager = TourManager()
        manager.start(MockTour.self)

        manager.next()

        #expect(manager.currentStepIndex == 1)
        #expect(manager.currentStep?.id == "step2")
    }

    @Test func nextOnLastStepCompletesTour() {
        let manager = TourManager()
        manager.start(MockTour.self)

        manager.next()
        manager.next()
        manager.next()

        #expect(!manager.isActive)
        #expect(manager.isCompleted(MockTour.self))
    }

    @Test func skipCompletesTourImmediately() {
        let manager = TourManager()
        manager.start(MockTour.self)

        manager.skip()

        #expect(!manager.isActive)
        #expect(manager.isCompleted(MockTour.self))
    }

    @Test func startIfNeededDoesNotStartCompletedTour() {
        let manager = TourManager()
        manager.start(MockTour.self)
        manager.skip()

        let started = manager.startIfNeeded(MockTour.self)

        #expect(!started)
        #expect(!manager.isActive)
    }

    @Test func startIfNeededStartsUncompletedTour() {
        let manager = TourManager()

        let started = manager.startIfNeeded(MockTour.self)

        #expect(started)
        #expect(manager.isActive)
    }

    @Test func completionPersistsAcrossInstances() {
        let manager1 = TourManager()
        manager1.start(MockTour.self)
        manager1.skip()

        let manager2 = TourManager()
        #expect(manager2.isCompleted(MockTour.self))
    }

    @Test func resetAllToursClearsCompletion() {
        let manager = TourManager()
        manager.start(MockTour.self)
        manager.skip()
        manager.start(AnotherMockTour.self)
        manager.skip()

        TourManager.resetAllTours()

        let newManager = TourManager()
        #expect(!newManager.isCompleted(MockTour.self))
        #expect(!newManager.isCompleted(AnotherMockTour.self))
    }

    @Test func resetSpecificTourOnlyClearsThatTour() {
        let manager = TourManager()
        manager.start(MockTour.self)
        manager.skip()
        manager.start(AnotherMockTour.self)
        manager.skip()

        TourManager.resetTour(MockTour.self)

        let newManager = TourManager()
        #expect(!newManager.isCompleted(MockTour.self))
        #expect(newManager.isCompleted(AnotherMockTour.self))
    }

    @Test func currentStepIsNilWhenNotActive() {
        let manager = TourManager()

        #expect(manager.currentStep == nil)
    }

    @Test func startForcesRestartEvenIfCompleted() {
        let manager = TourManager()
        manager.start(MockTour.self)
        manager.skip()

        manager.start(MockTour.self)

        #expect(manager.isActive)
        #expect(manager.currentStepIndex == 0)
    }
}
