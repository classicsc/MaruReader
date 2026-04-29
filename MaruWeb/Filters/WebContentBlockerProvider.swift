// WebContentBlockerProvider.swift
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
import Observation
import os.log
import WebKit

/// Coordinates compilation and installation of the merged content rule list.
///
/// Listens for changes to the master toggle and the filter list storage, recompiles when
/// inputs change, and pushes the resulting rule list chunks onto every
/// `WKUserContentController` that has been registered with the provider.
@MainActor
@Observable
public final class WebContentBlockerProvider {
    public static let shared = WebContentBlockerProvider()

    /// Latest compiled rule list chunks. Empty when blocking is disabled or when no
    /// enabled list has contents on disk yet.
    public private(set) var installedRuleLists: [WKContentRuleList] = []
    public private(set) var installedCosmeticEngine: WebCosmeticFilterEngine?

    /// Most recent compile error, if any. Cleared on the next successful compile.
    public private(set) var lastCompileError: String?

    /// `true` once `start()` has run.
    public private(set) var isStarted = false

    @ObservationIgnored private let storage: WebFilterListStorage
    @ObservationIgnored private let compiler: WebContentRuleListCompiler
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let log = Logger(subsystem: "MaruWeb", category: "content-blocker")
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var entriesObservationTask: Task<Void, Never>?
    @ObservationIgnored private var lastEntriesFingerprint: String = ""
    @ObservationIgnored private var compileTask: Task<Void, Never>?
    @ObservationIgnored private var compileGeneration: Int = 0
    @ObservationIgnored private var registeredControllers: [WeakControllerBox] = []

    public init(
        storage: WebFilterListStorage = .shared,
        compiler: WebContentRuleListCompiler? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.storage = storage
        self.compiler = compiler ?? WebContentRuleListCompiler(storage: storage)
        self.defaults = defaults
    }

    // MARK: - Lifecycle

    public func start() {
        guard !isStarted else { return }
        isStarted = true
        storage.start()
        scheduleRecompile()

        let center = NotificationCenter.default
        let toggleObserver = center.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: defaults,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.scheduleRecompile() }
        }
        observers.append(toggleObserver)

        // Re-fingerprint entries whenever the storage publishes a new snapshot.
        startEntriesObservation()
    }

    /// Tears down observers/tasks. Useful in tests; the production singleton is started
    /// once and never stopped.
    public func stop() {
        isStarted = false
        compileTask?.cancel()
        compileTask = nil
        entriesObservationTask?.cancel()
        entriesObservationTask = nil
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }

    private func startEntriesObservation() {
        entriesObservationTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, self.isStarted else { return }
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    withObservationTracking {
                        _ = self.storage.entries
                    } onChange: {
                        continuation.resume()
                    }
                }
                guard !Task.isCancelled else { return }
                self.scheduleRecompile()
            }
        }
    }

    // MARK: - Configuration installation

    /// Installs the current rule lists onto the given configuration's user content
    /// controller and registers the controller for future updates. Safe to call multiple
    /// times for the same controller.
    public func install(into configuration: WKWebViewConfiguration) {
        let controller = configuration.userContentController
        registeredControllers.removeAll { $0.controller == nil }
        let alreadyRegistered = registeredControllers.contains { $0.controller === controller }
        if !alreadyRegistered {
            registeredControllers.append(WeakControllerBox(controller: controller))
            installCosmeticFiltering(into: controller)
        }
        applyRuleLists(installedRuleLists, to: controller, previous: [])
    }

    // MARK: - Recompilation

    private func scheduleRecompile() {
        compileGeneration += 1
        let generation = compileGeneration
        compileTask?.cancel()
        compileTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.recompileIfNeeded(generation: generation)
        }
    }

    private func recompileIfNeeded(generation: Int) async {
        let isEnabled = defaults.object(forKey: WebContentBlocker.isEnabledKey) as? Bool
            ?? WebContentBlocker.isEnabledDefault

        guard isEnabled else {
            applyCompiledRuleSetEverywhere(ruleLists: [], cosmeticEngine: nil)
            lastCompileError = nil
            lastEntriesFingerprint = ""
            return
        }

        let fingerprint = Self.fingerprint(of: storage.entries)
        if fingerprint == lastEntriesFingerprint, !installedRuleLists.isEmpty || installedCosmeticEngine != nil {
            return
        }

        do {
            let compiled = try await compiler.compileEnabled()
            // Discard if a newer compile has been scheduled while we were running.
            guard generation == compileGeneration, !Task.isCancelled else { return }
            lastCompileError = nil
            lastEntriesFingerprint = fingerprint
            applyCompiledRuleSetEverywhere(
                ruleLists: compiled?.ruleLists ?? [],
                cosmeticEngine: compiled?.cosmeticEngine
            )
        } catch {
            guard generation == compileGeneration, !Task.isCancelled else { return }
            log.error("Content rule list compilation failed: \(String(describing: error), privacy: .public)")
            lastCompileError = String(describing: error)
        }
    }

    private func applyCompiledRuleSetEverywhere(
        ruleLists: [WKContentRuleList],
        cosmeticEngine: WebCosmeticFilterEngine?
    ) {
        let previous = installedRuleLists
        installedRuleLists = ruleLists
        installedCosmeticEngine = cosmeticEngine
        registeredControllers.removeAll { $0.controller == nil }
        for box in registeredControllers {
            guard let controller = box.controller else { continue }
            applyRuleLists(ruleLists, to: controller, previous: previous)
        }
    }

    private func installCosmeticFiltering(into controller: WKUserContentController) {
        controller.addScriptMessageHandler(
            WebCosmeticFilterMessageHandler(provider: self),
            contentWorld: .page,
            name: WebCosmeticFilterUserScript.messageHandlerName
        )
        if let userScript = WebCosmeticFilterUserScript.makeUserScript() {
            controller.addUserScript(userScript)
        }
    }

    fileprivate func handleCosmeticFilterMessage(
        _ message: WKScriptMessage,
        replyHandler: @escaping @MainActor (Any?, String?) -> Void
    ) {
        guard let body = message.body as? [String: Any],
              let kind = body["kind"] as? String
        else {
            replyHandler(nil, nil)
            return
        }

        let isEnabled = defaults.object(forKey: WebContentBlocker.isEnabledKey) as? Bool
            ?? WebContentBlocker.isEnabledDefault
        guard isEnabled, let installedCosmeticEngine else {
            replyHandler(["enabled": false], nil)
            return
        }

        switch kind {
        case "initial":
            guard let urlString = body["url"] as? String,
                  let url = URL(string: urlString),
                  Self.isWebURL(url)
            else {
                replyHandler(["enabled": false], nil)
                return
            }
            let resources = installedCosmeticEngine.resources(for: url)
            replyHandler([
                "enabled": true,
                "hideSelectors": resources.hideSelectors,
                "proceduralActions": resources.proceduralActions,
                "exceptions": resources.exceptions,
                "injectedScript": resources.injectedScript,
                "genericHide": resources.genericHide,
            ], nil)

        case "selectors":
            let selectors = installedCosmeticEngine.hiddenClassIDSelectors(
                classes: body["classes"] as? [String] ?? [],
                ids: body["ids"] as? [String] ?? [],
                exceptions: body["exceptions"] as? [String] ?? []
            )
            replyHandler(["selectors": selectors], nil)

        default:
            replyHandler(nil, nil)
        }
    }

    private func applyRuleLists(
        _ ruleLists: [WKContentRuleList],
        to controller: WKUserContentController,
        previous: [WKContentRuleList]
    ) {
        // Add new lists before removing previous ones so there's no fail-open window
        // where requests could bypass blocking during the swap.
        let newIdentifiers = Set(ruleLists.map(\.identifier))
        for list in ruleLists where !previous.contains(where: { $0.identifier == list.identifier }) {
            controller.add(list)
        }
        for old in previous where !newIdentifiers.contains(old.identifier) {
            controller.remove(old)
        }
    }

    // MARK: - Helpers

    private static func fingerprint(of entries: [WebFilterListEntry]) -> String {
        entries
            .filter(\.isEnabled)
            .map { "\($0.id.uuidString):\($0.contentDigest ?? "-")" }
            .joined(separator: "|")
    }

    private static func isWebURL(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased()
        return scheme == "http" || scheme == "https"
    }
}

private final class WeakControllerBox {
    weak var controller: WKUserContentController?
    init(controller: WKUserContentController) {
        self.controller = controller
    }
}

private final class WebCosmeticFilterMessageHandler: NSObject, WKScriptMessageHandlerWithReply {
    weak var provider: WebContentBlockerProvider?

    init(provider: WebContentBlockerProvider) {
        self.provider = provider
    }

    func userContentController(
        _: WKUserContentController,
        didReceive message: WKScriptMessage,
        replyHandler: @escaping @MainActor (Any?, String?) -> Void
    ) {
        Task { @MainActor [weak self] in
            guard let provider = self?.provider else {
                replyHandler(nil, nil)
                return
            }
            provider.handleCosmeticFilterMessage(message, replyHandler: replyHandler)
        }
    }
}
