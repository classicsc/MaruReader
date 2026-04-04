// ApplicationBackgroundTaskRunner.swift
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

import Foundation

#if canImport(UIKit)
    import UIKit
#endif

struct ApplicationBackgroundTaskRunner {
    let run: @Sendable (
        _ name: String,
        _ expirationHandler: @escaping @Sendable () -> Void,
        _ operation: @escaping @Sendable () async -> Void
    ) async -> Void

    static let live = Self { name, expirationHandler, operation in
        #if canImport(UIKit)
            let identifier = await MainActor.run {
                UIApplication.shared.beginBackgroundTask(withName: name) {
                    expirationHandler()
                }
            }

            await operation()

            await MainActor.run {
                guard identifier != .invalid else { return }
                UIApplication.shared.endBackgroundTask(identifier)
            }
        #else
            await operation()
        #endif
    }
}
