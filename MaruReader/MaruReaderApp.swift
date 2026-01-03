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
            let returnURL = URL(string: "marureader://anki/x-success")
            await AnkiMobileURLOpenerStore.shared.configure(
                opener: UIApplicationURLOpener(),
                returnURL: returnURL
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
