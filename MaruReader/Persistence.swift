//
//  Persistence.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/1/25.
//

import CoreData

// Immutable wrapper for the shared Core Data model.
// Safe if the model is created once and never mutated afterwards.
final class CoreDataModel: @unchecked Sendable {
    static let shared = CoreDataModel()
    let model: NSManagedObjectModel
    private init() {
        guard let url = Bundle.main.url(forResource: "MaruReader", withExtension: "momd"),
              let m = NSManagedObjectModel(contentsOf: url)
        else {
            fatalError("Failed to load MaruReader.momd")
        }
        model = m
    }
}

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false, model: NSManagedObjectModel = CoreDataModel.shared.model) {
        CoreDataTransformers.register()
        container = NSPersistentContainer(name: "MaruReader", managedObjectModel: model)
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    private func newTaskContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true
        return context
    }
}
