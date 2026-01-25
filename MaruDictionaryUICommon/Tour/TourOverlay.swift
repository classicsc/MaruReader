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
        .position(placement.position)
        .transition(.opacity)
    }

    private func calculatePlacement(
        for step: TourStep,
        targetRect: CGRect,
        in geometry: GeometryProxy
    ) -> (position: CGPoint, edge: Edge) {
        let coachMarkWidth: CGFloat = 320
        let coachMarkHeight: CGFloat = 140
        let spacing: CGFloat = 16
        let edgePadding: CGFloat = 16

        let screenBounds = geometry.frame(in: .local)

        let preferredEdge = step.preferredCoachMarkPlacement
        let edges: [Edge] = [preferredEdge] + Edge.allCases.filter { $0 != preferredEdge }

        for edge in edges {
            let position = positionForEdge(
                edge,
                targetRect: targetRect,
                coachMarkSize: CGSize(width: coachMarkWidth, height: coachMarkHeight),
                spacing: spacing
            )

            if isPositionValid(
                position,
                coachMarkSize: CGSize(width: coachMarkWidth, height: coachMarkHeight),
                screenBounds: screenBounds,
                edgePadding: edgePadding
            ) {
                return (position, edge)
            }
        }

        let centerX = screenBounds.midX
        let centerY = screenBounds.midY
        return (CGPoint(x: centerX, y: centerY), .bottom)
    }

    private func positionForEdge(
        _ edge: Edge,
        targetRect: CGRect,
        coachMarkSize: CGSize,
        spacing: CGFloat
    ) -> CGPoint {
        let centerX = targetRect.midX
        let centerY = targetRect.midY

        switch edge {
        case .top:
            return CGPoint(
                x: centerX,
                y: targetRect.minY - spacing - coachMarkSize.height / 2
            )
        case .bottom:
            return CGPoint(
                x: centerX,
                y: targetRect.maxY + spacing + coachMarkSize.height / 2
            )
        case .leading:
            return CGPoint(
                x: targetRect.minX - spacing - coachMarkSize.width / 2,
                y: centerY
            )
        case .trailing:
            return CGPoint(
                x: targetRect.maxX + spacing + coachMarkSize.width / 2,
                y: centerY
            )
        }
    }

    private func isPositionValid(
        _ position: CGPoint,
        coachMarkSize: CGSize,
        screenBounds: CGRect,
        edgePadding: CGFloat
    ) -> Bool {
        let halfWidth = coachMarkSize.width / 2
        let halfHeight = coachMarkSize.height / 2

        let minX = position.x - halfWidth
        let maxX = position.x + halfWidth
        let minY = position.y - halfHeight
        let maxY = position.y + halfHeight

        return minX >= edgePadding &&
            maxX <= screenBounds.width - edgePadding &&
            minY >= edgePadding &&
            maxY <= screenBounds.height - edgePadding
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
