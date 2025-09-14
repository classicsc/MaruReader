//
//  MaruReaderApp.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/1/25.
//

import SwiftUI

@main
struct MaruReaderApp: App {
    let persistenceController = PersistenceController.shared
    let dictionaryImportManager = DictionaryImportManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(dictionaryImportManager)
        }
    }
}
