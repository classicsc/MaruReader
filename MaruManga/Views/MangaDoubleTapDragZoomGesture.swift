// MangaDoubleTapDragZoomGesture.swift
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

import SwiftUI
import UIKit

/// A `UIGestureRecognizer` that detects: tap → release → press-and-hold → vertical drag.
///
/// Used to drive a smooth, one-handed zoom adjustment in the manga reader.
/// Activation requires the second touch to remain down and move past
/// `activationThreshold`; otherwise the recognizer fails so SwiftUI's existing
/// double-tap-to-toggle-zoom path can fire normally.
final class MangaDoubleTapDragZoomGestureRecognizer: UIGestureRecognizer {
    /// Maximum interval between the first tap's release and the second touch-down.
    static let maxInterTapDelay: TimeInterval = 0.3
    /// Maximum movement, in points, of the first touch before it's no longer considered a tap.
    static let maxFirstTapMovement: CGFloat = 12
    /// Maximum distance, in points, between the first tap and second touch-down.
    static let maxInterTapDistance: CGFloat = 40
    /// Movement, in points, the second touch must travel before the gesture begins.
    static let activationThreshold: CGFloat = 6

    /// Location of the second touch when it began (gesture's anchor point).
    private(set) var startLocation: CGPoint = .zero
    /// Translation of the second touch from its start location.
    private(set) var translation: CGSize = .zero

    private enum Phase {
        case idle
        case firstTouchDown(start: CGPoint, beganAt: TimeInterval)
        case awaitingSecondTouch(firstTapEndedAt: TimeInterval, firstTapLocation: CGPoint)
        case secondTouchPending(start: CGPoint)
        case active
    }

    private var phase: Phase = .idle
    private var trackedTouch: UITouch?

    override func reset() {
        super.reset()
        phase = .idle
        trackedTouch = nil
        startLocation = .zero
        translation = .zero
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)

        // Any extra concurrent touch fails the gesture (lets pinch-to-zoom take over).
        if let existing = trackedTouch, !touches.contains(existing) || touches.count > 1 {
            failGesture()
            return
        }

        guard let touch = touches.first else {
            failGesture()
            return
        }

        switch phase {
        case .idle:
            phase = .firstTouchDown(
                start: touch.location(in: view),
                beganAt: touch.timestamp
            )
            trackedTouch = touch
        case let .awaitingSecondTouch(firstTapEndedAt, firstTapLocation):
            let now = touch.timestamp
            let location = touch.location(in: view)
            let dx = location.x - firstTapLocation.x
            let dy = location.y - firstTapLocation.y
            let distance = sqrt(dx * dx + dy * dy)
            guard
                now - firstTapEndedAt <= Self.maxInterTapDelay,
                distance <= Self.maxInterTapDistance
            else {
                failGesture()
                return
            }
            phase = .secondTouchPending(start: location)
            trackedTouch = touch
            startLocation = location
            translation = .zero
        default:
            failGesture()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let tracked = trackedTouch, touches.contains(tracked) else { return }
        let location = tracked.location(in: view)

        switch phase {
        case let .firstTouchDown(start, _):
            let dx = location.x - start.x
            let dy = location.y - start.y
            if sqrt(dx * dx + dy * dy) > Self.maxFirstTapMovement {
                failGesture()
            }
        case let .secondTouchPending(start):
            let dx = location.x - start.x
            let dy = location.y - start.y
            let distance = sqrt(dx * dx + dy * dy)
            if distance >= Self.activationThreshold {
                phase = .active
                translation = CGSize(width: dx, height: dy)
                state = .began
            }
        case .active:
            translation = CGSize(
                width: location.x - startLocation.x,
                height: location.y - startLocation.y
            )
            state = .changed
        default:
            break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        guard let tracked = trackedTouch, touches.contains(tracked) else { return }

        switch phase {
        case let .firstTouchDown(_, beganAt):
            // First tap released before any movement: arm waiting for second touch.
            phase = .awaitingSecondTouch(
                firstTapEndedAt: tracked.timestamp,
                firstTapLocation: tracked.location(in: view)
            )
            trackedTouch = nil
            _ = beganAt
        case .secondTouchPending:
            // Second touch lifted before activation movement: this is just a regular
            // double-tap. Fail so the SwiftUI double-tap exclusively path fires.
            failGesture()
        case .active:
            state = .ended
        default:
            failGesture()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        failGesture()
    }

    override func canPrevent(_: UIGestureRecognizer) -> Bool {
        // Once we're active, prevent SwiftUI's pan/swipe drag from also firing.
        // Before .began we never block other recognizers.
        state == .began || state == .changed
    }

    override func canBePrevented(by _: UIGestureRecognizer) -> Bool {
        false
    }

    private func failGesture() {
        if state == .possible {
            state = .failed
        } else if state == .began || state == .changed {
            state = .cancelled
        }
        phase = .idle
        trackedTouch = nil
    }
}

/// SwiftUI bridge for `MangaDoubleTapDragZoomGestureRecognizer`.
struct MangaDoubleTapDragZoomGesture: UIGestureRecognizerRepresentable {
    var onChanged: (CGPoint, CGSize) -> Void
    var onEnded: (CGPoint, CGSize) -> Void
    var onCancelled: () -> Void

    func makeUIGestureRecognizer(context _: Context) -> MangaDoubleTapDragZoomGestureRecognizer {
        MangaDoubleTapDragZoomGestureRecognizer()
    }

    func handleUIGestureRecognizerAction(
        _ recognizer: MangaDoubleTapDragZoomGestureRecognizer,
        context _: Context
    ) {
        switch recognizer.state {
        case .began, .changed:
            onChanged(recognizer.startLocation, recognizer.translation)
        case .ended:
            onEnded(recognizer.startLocation, recognizer.translation)
        case .cancelled, .failed:
            onCancelled()
        default:
            break
        }
    }
}
