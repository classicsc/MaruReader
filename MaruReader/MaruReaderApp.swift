//
//  MaruReaderApp.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/1/25.
//

import MaruAnki
import MaruReaderCore
import SwiftUI

@main
struct MaruReaderApp: App {
    init() {
        Task { @MainActor in
            await AnkiMobileURLOpenerStore.shared.set(UIApplicationURLOpener())
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
