// SpotlightView.swift
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

/// A view that dims the screen except for a spotlight cutout around a target rect.
struct SpotlightView: View {
    let targetRect: CGRect
    let cornerRadius: CGFloat

    init(targetRect: CGRect, cornerRadius: CGFloat = 8) {
        self.targetRect = targetRect
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        GeometryReader { geometry in
            let fullRect = geometry.frame(in: .local)

            Canvas { context, _ in
                context.fill(
                    Path(fullRect),
                    with: .color(.black.opacity(0.6))
                )

                let padding: CGFloat = 4
                let paddedRect = targetRect.insetBy(dx: -padding, dy: -padding)
                let spotlightPath = Path(roundedRect: paddedRect, cornerRadius: cornerRadius + padding)

                context.blendMode = .destinationOut
                context.fill(spotlightPath, with: .color(.white))
            }
            .compositingGroup()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
