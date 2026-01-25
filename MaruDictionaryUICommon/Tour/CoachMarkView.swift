// CoachMarkView.swift
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

/// A tooltip-style view displaying tour step information with navigation buttons.
struct CoachMarkView: View {
    let step: TourStep
    let stepNumber: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onSkip: () -> Void

    private var isLastStep: Bool {
        stepNumber == totalSteps
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(step.title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(step.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("\(stepNumber) of \(totalSteps)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()

                if !isLastStep {
                    Button("Skip") {
                        onSkip()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Button(isLastStep ? "Done" : "Next") {
                    onNext()
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            }
        }
        .padding(16)
        .frame(maxWidth: 320)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
    }
}
