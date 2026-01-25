// TourOverlay.swift
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

/// Overlay that displays the tour spotlight and coach mark.
struct TourOverlayContent: View {
    let manager: TourManager
    let anchors: [String: Anchor<CGRect>]

    var body: some View {
        GeometryReader { geometry in
            if manager.isActive, let step = manager.currentStep {
                let targetRect = resolveTargetRect(for: step, in: geometry)

                ZStack {
                    SpotlightView(targetRect: targetRect)

                    coachMark(for: step, targetRect: targetRect, in: geometry)
                }
                .animation(.easeInOut(duration: 0.3), value: manager.currentStepIndex)
            }
        }
        .ignoresSafeArea()
    }

    private func resolveTargetRect(for step: TourStep, in geometry: GeometryProxy) -> CGRect {
        if let anchor = anchors[step.id] {
            return geometry[anchor]
        }
        return CGRect(x: geometry.size.width / 2 - 50, y: geometry.size.height / 2 - 25, width: 100, height: 50)
    }

    @ViewBuilder
    private func coachMark(for step: TourStep, targetRect: CGRect, in geometry: GeometryProxy) -> some View {
        let placement = calculatePlacement(for: step, targetRect: targetRect, in: geometry)

        CoachMarkView(
            step: step,
            stepNumber: manager.currentStepIndex + 1,
            totalSteps: manager.currentTourSteps.count,
            onNext: { manager.next() },
            onSkip: { manager.skip() }
        )
        .position(placement)
        .transition(.opacity)
    }

    private func calculatePlacement(
        for _: TourStep,
        targetRect: CGRect,
        in geometry: GeometryProxy
    ) -> CGPoint {
        let coachMarkHeight: CGFloat = 140
        let spacing: CGFloat = 16

        let screenBounds = geometry.frame(in: .local)
        let centerX = screenBounds.midX

        // Determine if target is in top or bottom half of screen
        let targetCenterY = targetRect.midY
        let isTargetInTopHalf = targetCenterY < screenBounds.midY

        // Place coach mark on opposite side of screen from target
        let coachMarkY: CGFloat = if isTargetInTopHalf {
            // Target in top half: place coach mark in bottom area
            screenBounds.maxY - spacing - coachMarkHeight / 2 - 40
        } else {
            // Target in bottom half: place coach mark in top area
            screenBounds.minY + spacing + coachMarkHeight / 2 + 60
        }

        return CGPoint(x: centerX, y: coachMarkY)
    }
}

/// View modifier that adds tour overlay capability to a view.
struct TourOverlayModifier: ViewModifier {
    let manager: TourManager

    func body(content: Content) -> some View {
        content
            .overlayPreferenceValue(TourAnchorPreferenceKey.self) { anchors in
                TourOverlayContent(manager: manager, anchors: anchors)
            }
    }
}

public extension View {
    /// Adds a tour overlay that can highlight elements marked with `.tourAnchor(_:)`.
    func tourOverlay(manager: TourManager) -> some View {
        modifier(TourOverlayModifier(manager: manager))
    }
}
