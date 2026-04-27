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
        ))

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
        StubURLProtocol.set(StubURLProtocol.Response(statusCode: 304, body: Data(), headers: [:]))

        let outcome = await env.downloader.refresh(entry: refreshed)
        #expect(outcome == .notModified)
        #expect(env.storage.loadContents(for: entry.id) == "||old^")
        let after = try #require(env.storage.entries.first { $0.id == entry.id })
        #expect((after.lastFetchSuccessAt ?? .distantPast) > earlier)
    }

    @Test func refresh_withNetworkError_recordsLastFetchError() async throws {
        let env = try makeEnv()
        let entry = try add(env: env, url: "https://example.com/c.txt")
        StubURLProtocol.setError(URLError(.notConnectedToInternet))

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
        StubURLProtocol.set(StubURLProtocol.Response(statusCode: 500, body: Data(), headers: [:]))

        let outcome = await env.downloader.refresh(entry: entry)
        if case .failed = outcome {
            // ok
        } else {
            Issue.record("Expected .failed, got \(outcome)")
        }
        let updated = env.storage.entries.first { $0.id == entry.id }
        #expect(updated?.lastFetchError?.contains("500") == true)
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
    struct Response {
        let statusCode: Int
        let body: Data
        let headers: [String: String]
    }

    private static let lock = NSLock()
    private nonisolated(unsafe) static var pendingResponse: Response?
    private nonisolated(unsafe) static var pendingError: Error?

    static func set(_ response: Response) {
        lock.lock(); defer { lock.unlock() }
        pendingResponse = response
        pendingError = nil
    }

    static func setError(_ error: Error) {
        lock.lock(); defer { lock.unlock() }
        pendingError = error
        pendingResponse = nil
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.lock()
        let response = Self.pendingResponse
        let error = Self.pendingError
        Self.lock.unlock()

        if let error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        guard let response, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: response.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: response.headers
        )!
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
