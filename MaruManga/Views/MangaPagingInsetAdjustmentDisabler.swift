// MangaPagingInsetAdjustmentDisabler.swift
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

/// SwiftUI's paged `TabView` lets UIKit inset its collection view for any safe area it overlaps.
/// On iPhone Duo's outer display that is an 84 pt status strip on one side only, so each page is
/// centered off the viewport and the neighbor's edge shows. With the adjustment off, pages fill
/// the full bounds and bleed under the strip the way they do under a regular iPhone's status bar.
/// Place it as the `TabView`'s background; it finds the paging scroll view from there.
struct MangaPagingInsetAdjustmentDisabler: UIViewRepresentable {
    func makeUIView(context _: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_: ProbeView, context _: Context) {}

    final class ProbeView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            disableAdjustment()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            disableAdjustment()
        }

        private func disableAdjustment() {
            var ancestor = superview
            while let view = ancestor, !(view is UIWindow) {
                if let paging = view.firstPagingScrollView() {
                    if paging.contentInsetAdjustmentBehavior != .never {
                        paging.contentInsetAdjustmentBehavior = .never
                    }
                    return
                }
                ancestor = view.superview
            }
        }
    }
}

private extension UIView {
    func firstPagingScrollView() -> UIScrollView? {
        if let scrollView = self as? UIScrollView, scrollView.isPagingEnabled {
            return scrollView
        }
        for subview in subviews {
            if let found = subview.firstPagingScrollView() {
                return found
            }
        }
        return nil
    }
}
