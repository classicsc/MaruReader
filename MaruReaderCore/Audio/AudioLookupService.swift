//
//  AudioLookupService.swift
//  MaruReader
//
//  Created by Sam Smoker on 12/12/25.
//

import CoreData
import Foundation
import os.log

/// Central service for audio lookups across all configured sources
public actor AudioLookupService {
    // MARK: - Internal Types

    /// Internal representation of an audio source provider
    private struct AudioProvider {
        let sourceID: UUID
        let name: String
        let type: AudioSourceType
        let priority: Int64
        let isLocal: Bool
        let baseRemoteURL: String?
    }

    // MARK: - Properties

    private var providers: [AudioProvider] = []
    private var cache: [String: AudioLookupResult] = [:] // Session cache

    private let persistenceController: DictionaryPersistenceController

    // Observation tasks for auto-reload
    private var observationTask: Task<Void, Never>?
    private var reloadDebounceTask: Task<Void, Error>?

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "AudioLookupService")

    // MARK: - Initialization

    public init(persistenceController: DictionaryPersistenceController) {
        self.persistenceController = persistenceController
    }

    // MARK: - Provider Management

    /// Initialize providers from Core Data configuration and start observing for changes
    public func loadProviders() async throws {
        try await loadProvidersInternal()

        // Start observation if not already running
        if observationTask == nil {
            startObservingAudioSourceChanges()
            logger.debug("Started observing AudioSource changes")
        }
    }

    /// Internal method to load providers from Core Data
    private func loadProvidersInternal() async throws {
        let context = persistenceController.newBackgroundContext()

        let sources: [(UUID, String, AudioSourceType, Int64, Bool, String?)] = try await context.perform {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "AudioSource")
            request.predicate = NSPredicate(format: "enabled == YES")
            request.sortDescriptors = [NSSortDescriptor(key: "priority", ascending: true)]

            guard let results = try context.fetch(request) as? [NSManagedObject] else {
                return []
            }

            return results.compactMap { source in
                guard let id = source.value(forKey: "id") as? UUID,
                      let name = source.value(forKey: "name") as? String,
                      let priority = source.value(forKey: "priority") as? Int64,
                      let isLocal = source.value(forKey: "isLocal") as? Bool
                else {
                    return nil
                }

                let baseRemoteURL = source.value(forKey: "baseRemoteURL") as? String
                let indexedByHeadword = source.value(forKey: "indexedByHeadword") as? Bool ?? false
                let urlPattern = source.value(forKey: "urlPattern") as? String

                let type: AudioSourceType
                if indexedByHeadword {
                    type = .indexed(id)
                } else if let pattern = urlPattern {
                    type = .urlPattern(pattern)
                } else {
                    return nil // Invalid source configuration
                }

                return (id, name, type, priority, isLocal, baseRemoteURL)
            }
        }

        providers = sources.map {
            AudioProvider(
                sourceID: $0.0,
                name: $0.1,
                type: $0.2,
                priority: $0.3,
                isLocal: $0.4,
                baseRemoteURL: $0.5
            )
        }
    }

    // MARK: - Change Observation

    /// Start observing Core Data changes for AudioSource entities
    private func startObservingAudioSourceChanges() {
        // Cancel existing observation if any
        observationTask?.cancel()

        observationTask = Task {
            let notificationSequence = NotificationCenter.default.notifications(
                named: NSNotification.Name.NSManagedObjectContextDidSave
            )

            for await notification in notificationSequence {
                if containsAudioSourceChanges(notification) {
                    logger.debug("AudioSource changes detected, scheduling reload")
                    scheduleReload()
                }
            }
        }
    }

    /// Check if a Core Data save notification contains AudioSource entity changes
    private func containsAudioSourceChanges(_ notification: Notification) -> Bool {
        guard let userInfo = notification.userInfo else { return false }

        let inserted = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
        let updated = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
        let deleted = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []

        let allChangedObjects = inserted.union(updated).union(deleted)

        return allChangedObjects.contains { object in
            object.entity.name == "AudioSource"
        }
    }

    /// Schedule a provider reload with debouncing to handle rapid changes
    private func scheduleReload() {
        reloadDebounceTask?.cancel()
        reloadDebounceTask = Task {
            try await Task.sleep(nanoseconds: 250_000_000) // 250ms debounce
            try Task.checkCancellation()
            do {
                try await self.reloadProviders()
            } catch {
                logger.error("Failed to reload providers: \(error.localizedDescription)")
            }
        }
    }

    /// Reload providers and clear cache
    private func reloadProviders() async throws {
        logger.debug("Reloading audio providers")
        cache.removeAll()
        try await loadProvidersInternal()
        logger.info("Audio providers reloaded successfully")
    }

    // MARK: - Audio Lookup

    /// Look up audio for a term/reading pair
    public func lookupAudio(for request: AudioLookupRequest) async -> AudioLookupResult {
        let cacheKey = "\(request.term)|\(request.reading ?? "")"

        if let cached = cache[cacheKey] {
            return cached
        }

        var allResults: [AudioSourceResult] = []

        for provider in providers {
            do {
                let results = try await getSourceResults(for: request, from: provider)
                allResults.append(contentsOf: results)
            } catch {
                // Log but continue to next provider
                continue
            }
        }

        let result = AudioLookupResult(request: request, sources: allResults)
        cache[cacheKey] = result
        return result
    }

    /// Batch lookup for multiple terms (used in search results)
    public func lookupAudio(for requests: [AudioLookupRequest]) async -> [AudioLookupResult] {
        await withTaskGroup(of: AudioLookupResult.self) { group in
            for request in requests {
                group.addTask { await self.lookupAudio(for: request) }
            }

            var results: [AudioLookupResult] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }

    // MARK: - Private Methods

    /// Get audio results from a specific provider
    private func getSourceResults(for request: AudioLookupRequest, from provider: AudioProvider) async throws -> [AudioSourceResult] {
        switch provider.type {
        case let .urlPattern(pattern):
            getURLPatternResults(for: request, from: provider, pattern: pattern)

        case let .indexed(sourceID):
            try await getIndexedResults(for: request, from: provider, sourceID: sourceID)
        }
    }

    /// Get results from a URL pattern source
    private func getURLPatternResults(for request: AudioLookupRequest, from provider: AudioProvider, pattern: String) -> [AudioSourceResult] {
        var urlString = pattern
        urlString = urlString.replacingOccurrences(of: "{term}", with: request.term)
        urlString = urlString.replacingOccurrences(of: "{reading}", with: request.reading ?? "")
        urlString = urlString.replacingOccurrences(of: "{language}", with: request.language)

        guard let url = URL(string: urlString) else {
            return []
        }

        return [AudioSourceResult(
            url: url,
            sourceName: provider.name,
            sourceType: provider.type,
            isLocal: provider.isLocal,
            pitchNumber: nil // URL pattern sources don't have pitch info
        )]
    }

    /// Get results from an indexed source
    private func getIndexedResults(for request: AudioLookupRequest, from provider: AudioProvider, sourceID: UUID) async throws -> [AudioSourceResult] {
        let context = persistenceController.newBackgroundContext()

        return try await context.perform {
            // Fetch AudioHeadword matching the term
            let headwordRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "AudioHeadword")
            headwordRequest.predicate = NSPredicate(
                format: "expression == %@ AND sourceID == %@",
                request.term,
                sourceID as CVarArg
            )

            guard let headwords = try context.fetch(headwordRequest) as? [NSManagedObject],
                  let headword = headwords.first,
                  let filesJSON = headword.value(forKey: "files") as? String
            else {
                return []
            }

            // Decode the files JSON array
            guard let filesData = filesJSON.data(using: .utf8),
                  let fileNames = try? JSONDecoder().decode([String].self, from: filesData)
            else {
                return []
            }

            // Fetch AudioFile entries matching the file names and reading
            let fileRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "AudioFile")

            var predicates = [
                NSPredicate(format: "name IN %@", fileNames),
                NSPredicate(format: "sourceID == %@", sourceID as CVarArg),
            ]

            if let reading = request.reading {
                predicates.append(NSPredicate(format: "normalizedReading == %@", reading))
            }

            fileRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

            guard let audioFiles = try context.fetch(fileRequest) as? [NSManagedObject] else {
                return []
            }

            // Separate results by pitch match
            var matchingPitch: [AudioSourceResult] = []
            var otherResults: [AudioSourceResult] = []

            for audioFile in audioFiles {
                guard let fileName = audioFile.value(forKey: "name") as? String else {
                    continue
                }

                let url: URL
                if provider.isLocal {
                    url = URL(string: "marureader-audio://\(sourceID.uuidString)/\(fileName)")!
                } else if let baseURL = provider.baseRemoteURL {
                    url = URL(string: baseURL)!.appendingPathComponent(fileName)
                } else {
                    continue // No base URL for remote source
                }

                // Extract pitch number from the audio file, converting empty string to nil
                let filePitchNumber = audioFile.value(forKey: "pitchNumber") as? String
                let normalizedPitchNumber = filePitchNumber.flatMap { $0.isEmpty ? nil : $0 }

                let result = AudioSourceResult(
                    url: url,
                    sourceName: provider.name,
                    sourceType: provider.type,
                    isLocal: provider.isLocal,
                    pitchNumber: normalizedPitchNumber
                )

                // Check if pitch matches the request's downstep position
                if let requestedPitch = request.downstepPosition,
                   normalizedPitchNumber == requestedPitch
                {
                    matchingPitch.append(result)
                } else {
                    otherResults.append(result)
                }
            }

            // Prioritize pitch-matching results
            return matchingPitch + otherResults
        }
    }
}
