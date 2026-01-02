//
//  AnkiMobileURLOpener.swift
//  MaruReader
//

import MaruAnki
import UIKit

struct UIApplicationURLOpener: AnkiMobileURLOpening {
    func open(_ url: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                UIApplication.shared.open(url, options: [:]) { success in
                    continuation.resume(returning: success)
                }
            }
        }
    }
}
