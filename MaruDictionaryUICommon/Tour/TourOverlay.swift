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
                let anchorPoint = attachmentPoint(for: step.popoverEdge, in: targetRect, geometry: geometry)
                let arrowEdge = arrowEdge(for: step.popoverEdge)

                SpotlightView(targetRect: targetRect)
                    .animation(.easeInOut(duration: 0.3), value: manager.currentStepIndex)
                    .popover(
                        isPresented: .constant(true),
                        attachmentAnchor: .point(anchorPoint),
                        arrowEdge: arrowEdge
                    ) {
                        CoachMarkView(
                            step: step,
                            stepNumber: manager.currentStepIndex + 1,
                            totalSteps: manager.currentTourSteps.count,
                            onNext: { manager.next() },
                            onSkip: { manager.skip() }
                        )
                        .presentationCompactAdaptation(.popover)
                        .interactiveDismissDisabled(true)
                    }
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

    private func attachmentPoint(for edge: Edge, in rect: CGRect, geometry: GeometryProxy) -> UnitPoint {
        let size = geometry.size
        let normalizedMidX = rect.midX / size.width
        let normalizedMidY = rect.midY / size.height
        switch edge {
        case .top:
            return UnitPoint(x: normalizedMidX, y: rect.minY / size.height)
        case .bottom:
            return UnitPoint(x: normalizedMidX, y: rect.maxY / size.height)
        case .leading:
            return UnitPoint(x: rect.minX / size.width, y: normalizedMidY)
        case .trailing:
            return UnitPoint(x: rect.maxX / size.width, y: normalizedMidY)
        }
    }

    private func arrowEdge(for popoverEdge: Edge) -> Edge {
        switch popoverEdge {
        case .top: .bottom
        case .bottom: .top
        case .leading: .trailing
        case .trailing: .leading
        }
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
