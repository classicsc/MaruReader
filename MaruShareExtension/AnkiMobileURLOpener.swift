//
//  AnkiMobileURLOpener.swift
//  MaruShareExtension
//

import MaruAnki
import UIKit

final class ExtensionContextURLOpener: AnkiMobileURLOpening, @unchecked Sendable {
    private weak var context: NSExtensionContext?

    init(context: NSExtensionContext?) {
        self.context = context
    }

    func open(_ url: URL) async -> Bool {
        guard let context else { return false }

        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                context.open(url) { success in
                    continuation.resume(returning: success)
                }
            }
        }
    }
}
