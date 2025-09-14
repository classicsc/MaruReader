//
//  ContentView.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/1/25.
//

import CoreData
import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Dictionary.title, ascending: true)],
        animation: .default
    )
    private var items: FetchedResults<Dictionary>

    var body: some View {
        List {
            ForEach(items) { item in
                Text("Item at \(item.title ?? "No title")")
            }
        }
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
