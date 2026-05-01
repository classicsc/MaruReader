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
    private var secondTapTimeoutTimer: Timer?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationInterruption),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationInterruption),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        MainActor.assumeIsolated {
            secondTapTimeoutTimer?.invalidate()
        }
    }

    override func reset() {
        super.reset()
        cancelSecondTapTimeout()
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
            cancelSecondTapTimeout()
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
            scheduleSecondTapTimeout()
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
        cancelSecondTapTimeout()
        if state == .possible {
            state = .failed
        } else if state == .began || state == .changed {
            state = .cancelled
        }
        clearGestureState()
    }

    private func scheduleSecondTapTimeout() {
        cancelSecondTapTimeout()
        secondTapTimeoutTimer = Timer.scheduledTimer(withTimeInterval: Self.maxInterTapDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleSecondTapTimeout()
            }
        }
    }

    private func cancelSecondTapTimeout() {
        secondTapTimeoutTimer?.invalidate()
        secondTapTimeoutTimer = nil
    }

    private func handleSecondTapTimeout() {
        secondTapTimeoutTimer = nil
        guard case .awaitingSecondTouch = phase else { return }
        failGesture()
    }

    @objc private func handleApplicationInterruption() {
        guard !isIdle else { return }
        failGesture()
    }

    private var isIdle: Bool {
        if case .idle = phase {
            return true
        }
        return false
    }

    private func clearGestureState() {
        phase = .idle
        trackedTouch = nil
        startLocation = .zero
        translation = .zero
    }
}

#if DEBUG
    extension MangaDoubleTapDragZoomGestureRecognizer {
        enum DebugPhase: Equatable {
            case idle
            case firstTouchDown
            case awaitingSecondTouch
            case secondTouchPending
            case active
        }

        var debugPhase: DebugPhase {
            switch phase {
            case .idle:
                .idle
            case .firstTouchDown:
                .firstTouchDown
            case .awaitingSecondTouch:
                .awaitingSecondTouch
            case .secondTouchPending:
                .secondTouchPending
            case .active:
                .active
            }
        }

        var debugHasSecondTapTimeout: Bool {
            secondTapTimeoutTimer != nil
        }

        func debugEnterAwaitingSecondTouch() {
            phase = .awaitingSecondTouch(firstTapEndedAt: 0, firstTapLocation: .zero)
            trackedTouch = nil
            scheduleSecondTapTimeout()
        }

        func debugEnterActiveGesture() {
            cancelSecondTapTimeout()
            phase = .active
            startLocation = CGPoint(x: 20, y: 20)
            translation = CGSize(width: 0, height: 10)
            state = .began
        }

        func debugFireSecondTapTimeout() {
            handleSecondTapTimeout()
        }

        func debugHandleApplicationInterruption() {
            handleApplicationInterruption()
        }
    }
#endif

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
