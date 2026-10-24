// WebStatusStrip.swift
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

/// iPhone Duo keeps the status bar and camera on one long edge instead of the top, so its safe
/// area has a horizontal inset on that edge only. Regular iPhones inset both edges in landscape
/// and never qualify. On the outer display (compact width) the whole strip is reserved and the
/// system puts its tab bar there; on the inner display (regular width) only the status block at
/// the top of the strip is occluded.
struct WebStatusStrip: Equatable {
    let edge: HorizontalEdge
    let width: CGFloat

    init(edge: HorizontalEdge, width: CGFloat) {
        self.edge = edge
        self.width = width
    }

    init?(safeAreaInsets: EdgeInsets) {
        switch (safeAreaInsets.leading > 0, safeAreaInsets.trailing > 0) {
        case (true, false): self.init(edge: .leading, width: safeAreaInsets.leading)
        case (false, true): self.init(edge: .trailing, width: safeAreaInsets.trailing)
        default: return nil
        }
    }

    var edgeSet: Edge.Set {
        edge == .leading ? .leading : .trailing
    }

    /// Where a side toolbar goes: the strip's edge, at whichever end the camera is not.
    func alignment(occludesBottom: Bool) -> Alignment {
        switch (edge, occludesBottom) {
        case (.leading, false): .bottomLeading
        case (.leading, true): .topLeading
        case (.trailing, false): .bottomTrailing
        case (.trailing, true): .topTrailing
        }
    }
}

/// Reports whether the camera and status block occlude the bottom half of the strip. They sit in
/// one hardware corner, so rotation moves them between the strip's ends, and SwiftUI has no
/// reserved-region API of its own. Place it inside the strip; it reads UIKit's regions from there.
struct WebStripOcclusionProbe: UIViewRepresentable {
    let onChange: @MainActor (Bool) -> Void

    func makeUIView(context _: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        view.onChange = onChange
        return view
    }

    func updateUIView(_ view: ProbeView, context _: Context) {
        view.onChange = onChange
    }

    final class ProbeView: UIView {
        var onChange: (@MainActor (Bool) -> Void)?
        private var occludesBottom: Bool?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        private func report() {
            guard #available(iOS 27.1, *), window != nil, bounds.height > 0 else { return }
            let occluded = reservedRegions(kind: .occlusion)
                .map(\.frame)
                .filter { $0.intersects(bounds) }
                .reduce(CGRect.null) { $0.union($1) }
            let occludesBottom = !occluded.isNull && occluded.midY > bounds.midY
            guard occludesBottom != self.occludesBottom else { return }
            self.occludesBottom = occludesBottom
            onChange?(occludesBottom)
        }
    }
}
