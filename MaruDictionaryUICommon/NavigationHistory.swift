//  NavigationHistory.swift
//  MaruReader
//
//  Navigation history manager for dictionary search back/forward navigation.
//
import Foundation
import MaruReaderCore

/// A single entry in the navigation history
struct HistoryEntry: Sendable {
    let request: TextLookupRequest
    let response: TextLookupResponse
}

/// Manages back/forward navigation history for dictionary searches
@MainActor
@Observable
final class NavigationHistory {
    private var backStack: [HistoryEntry] = []
    private var forwardStack: [HistoryEntry] = []
    private(set) var currentEntry: HistoryEntry?

    private let maxHistorySize = 50

    /// Whether navigation backwards is possible
    var canGoBack: Bool {
        !backStack.isEmpty
    }

    /// Whether navigation forwards is possible
    var canGoForward: Bool {
        !forwardStack.isEmpty
    }

    /// Push a new history entry, clearing the forward stack
    func push(request: TextLookupRequest, response: TextLookupResponse) {
        // Save current entry to back stack if it exists
        if let current = currentEntry {
            backStack.append(current)

            // Enforce max history size by removing oldest entries
            if backStack.count > maxHistorySize {
                backStack.removeFirst(backStack.count - maxHistorySize)
            }
        }

        // Clear forward stack when new navigation occurs
        forwardStack.removeAll()

        // Set new current entry
        currentEntry = HistoryEntry(request: request, response: response)
    }

    /// Navigate backwards, returning the previous entry
    func goBack() -> HistoryEntry? {
        guard let current = currentEntry, !backStack.isEmpty else {
            return nil
        }

        // Move current to forward stack
        forwardStack.append(current)

        // Pop from back stack and make it current
        let previousEntry = backStack.removeLast()
        currentEntry = previousEntry

        return previousEntry
    }

    /// Navigate forwards, returning the next entry
    func goForward() -> HistoryEntry? {
        guard let current = currentEntry, !forwardStack.isEmpty else {
            return nil
        }

        // Move current to back stack
        backStack.append(current)

        // Enforce max history size
        if backStack.count > maxHistorySize {
            backStack.removeFirst(backStack.count - maxHistorySize)
        }

        // Pop from forward stack and make it current
        let nextEntry = forwardStack.removeLast()
        currentEntry = nextEntry

        return nextEntry
    }

    /// Clear all history
    func clear() {
        backStack.removeAll()
        forwardStack.removeAll()
        currentEntry = nil
    }
}
