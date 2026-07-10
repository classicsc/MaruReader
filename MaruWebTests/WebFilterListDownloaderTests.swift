// WebFilterListDownloaderTests.swift
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
@testable import MaruWeb
import Synchronization
import Testing

@MainActor
struct WebFilterListDownloaderTests {
    @Test func refresh_with200_storesContentsAndEtag() async throws {
        let env = try makeEnv()
        let entry = try add(env: env, url: "https://example.com/a.txt")
        StubURLProtocol.set(StubURLProtocol.Response(
            statusCode: 200,
            body: Data("||ads^".utf8),
            headers: ["Etag": "\"v1\""]
        ), for: entry.sourceURL)

        let outcome = await env.downloader.refresh(entry: entry)
        if case .updated = outcome {
            // ok
        } else {
            Issue.record("Expected .updated, got \(outcome)")
        }
        let updated = env.storage.entries.first { $0.id == entry.id }
        #expect(updated?.etag == "\"v1\"")
        #expect(env.storage.loadContents(for: entry.id) == "||ads^")
    }

    @Test func refresh_with304_keepsContentsButBumpsSuccess() async throws {
        let env = try makeEnv()
        let entry = try add(env: env, url: "https://example.com/b.txt")
        try env.storage.applyDownloadSuccess(
            id: entry.id, contents: "||old^",
            etag: "\"v0\"", lastModified: nil,
            attemptedAt: Date(), succeededAt: Date(timeIntervalSinceNow: -3600)
        )
        let refreshed = try #require(env.storage.entries.first { $0.id == entry.id })
        let earlier = try #require(refreshed.lastFetchSuccessAt)
        StubURLProtocol.set(
            StubURLProtocol.Response(statusCode: 304, body: Data(), headers: [:]),
            for: entry.sourceURL
        )

        let outcome = await env.downloader.refresh(entry: refreshed)
        #expect(outcome == .notModified)
        #expect(env.storage.loadContents(for: entry.id) == "||old^")
        let after = try #require(env.storage.entries.first { $0.id == entry.id })
        #expect((after.lastFetchSuccessAt ?? .distantPast) > earlier)
    }

    @Test func refresh_withNetworkError_recordsLastFetchError() async throws {
        let env = try makeEnv()
        let entry = try add(env: env, url: "https://example.com/c.txt")
        StubURLProtocol.setError(URLError(.notConnectedToInternet), for: entry.sourceURL)

        let outcome = await env.downloader.refresh(entry: entry)
        if case .failed = outcome {
            // ok
        } else {
            Issue.record("Expected .failed, got \(outcome)")
        }
        let updated = env.storage.entries.first { $0.id == entry.id }
        #expect(updated?.lastFetchError != nil)
    }

    @Test func refresh_with500_recordsLastFetchError() async throws {
        let env = try makeEnv()
        let entry = try add(env: env, url: "https://example.com/d.txt")
        StubURLProtocol.set(
            StubURLProtocol.Response(statusCode: 500, body: Data(), headers: [:]),
            for: entry.sourceURL
        )

        let outcome = await env.downloader.refresh(entry: entry)
        if case .failed = outcome {
            // ok
        } else {
            Issue.record("Expected .failed, got \(outcome)")
        }
        let updated = env.storage.entries.first { $0.id == entry.id }
        #expect(updated?.lastFetchError?.contains("500") == true)
    }

    @Test func refreshAll_cancellationStopsActiveRequestsWithoutRecordingFailures() async throws {
        let env = try makeEnv()
        let started = CountGate()
        let stopped = CountGate()
        var entries: [WebFilterListEntry] = []

        for index in 0 ..< 5 {
            let entry = try add(env: env, url: "https://example.com/cancel-\(index).txt")
            try env.storage.applyDownloadSuccess(
                id: entry.id,
                contents: "||old-\(index)^",
                etag: nil,
                lastModified: nil,
                attemptedAt: Date(),
                succeededAt: Date()
            )
            entries.append(entry)
            StubURLProtocol.setHanging(
                for: entry.sourceURL,
                onStart: { Task { await started.signal() } },
                onStop: { Task { await stopped.signal() } }
            )
        }

        let task = Task {
            await env.downloader.refreshAll()
        }
        await started.wait(for: 3)
        task.cancel()
        _ = await task.value
        await stopped.wait(for: 3)

        #expect(StubURLProtocol.requestCount(for: entries.map(\.sourceURL)) == 3)
        for (index, entry) in entries.enumerated() {
            let updated = try #require(env.storage.entries.first { $0.id == entry.id })
            #expect(updated.lastFetchError == nil)
            #expect(env.storage.loadContents(for: entry.id) == "||old-\(index)^")
        }
    }

    // MARK: - Helpers

    private struct Env {
        let storage: WebFilterListStorage
        let downloader: WebFilterListDownloader
    }

    private func makeEnv() throws -> Env {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MaruWebDownloaderTests-\(UUID().uuidString)")
        let controller = makeWebPersistenceController()
        let storage = WebFilterListStorage(
            persistenceController: controller,
            fileManager: .default,
            filterListsDirectory: directory
        )
        storage.start()

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        let downloader = WebFilterListDownloader(session: session, storage: storage)
        return Env(storage: storage, downloader: downloader)
    }

    private func add(env: Env, url: String) throws -> WebFilterListEntry {
        guard let entry = env.storage.add(seed: WebFilterListSeed(
            name: "T",
            sourceURL: URL(string: url)!,
            format: .standard
        )) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return entry
    }
}

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Response: Sendable {
        let statusCode: Int
        let body: Data
        let headers: [String: String]
    }

    private enum Stub: Sendable {
        case response(Response)
        case error(any Error & Sendable)
        case hanging(onStart: @Sendable () -> Void, onStop: @Sendable () -> Void)
    }

    private struct State: Sendable {
        var stubs: [URL: Stub] = [:]
        var requestCounts: [URL: Int] = [:]
    }

    private static let state = Mutex(State())
    private var stopHandler: (@Sendable () -> Void)?

    static func set(_ response: Response, for url: URL) {
        state.withLock { state in
            state.stubs[url] = .response(response)
        }
    }

    static func setError(_ error: some Error & Sendable, for url: URL) {
        state.withLock { state in
            state.stubs[url] = .error(error)
        }
    }

    static func setHanging(
        for url: URL,
        onStart: @escaping @Sendable () -> Void,
        onStop: @escaping @Sendable () -> Void
    ) {
        state.withLock { state in
            state.stubs[url] = .hanging(onStart: onStart, onStop: onStop)
        }
    }

    static func requestCount(for urls: [URL]) -> Int {
        state.withLock { state in
            urls.reduce(0) { $0 + state.requestCounts[$1, default: 0] }
        }
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let stub = Self.state.withLock { state in
            state.requestCounts[url, default: 0] += 1
            return state.stubs[url]
        }

        switch stub {
        case let .error(error):
            client?.urlProtocol(self, didFailWithError: error)
        case let .response(response):
            let httpResponse = HTTPURLResponse(
                url: url,
                statusCode: response.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: response.headers
            )!
            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: response.body)
            client?.urlProtocolDidFinishLoading(self)
        case let .hanging(onStart, onStop):
            stopHandler = onStop
            onStart()
        case nil:
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
        }
    }

    override func stopLoading() {
        let handler = stopHandler
        stopHandler = nil
        handler?()
    }
}

actor CountGate {
    private var count = 0
    private var waiters: [(target: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func signal() {
        count += 1
        let ready = waiters.filter { count >= $0.target }
        waiters.removeAll { count >= $0.target }
        for waiter in ready {
            waiter.continuation.resume()
        }
    }

    func wait(for target: Int) async {
        guard count < target else { return }
        await withCheckedContinuation { continuation in
            waiters.append((target, continuation))
        }
    }
}
