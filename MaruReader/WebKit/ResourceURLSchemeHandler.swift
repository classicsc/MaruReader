//
//  ResourceURLSchemeHandler.swift
//  MaruReader
//
//  URL scheme handler for marureader-resource:// scheme to serve app bundle resources like CSS files.
//

import Foundation
import os.log
import UniformTypeIdentifiers
import WebKit

@MainActor
class ResourceURLSchemeHandler: NSObject, URLSchemeHandler, WKURLSchemeHandler {
    private static let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "ResourceURLSchemeHandler")

    // Track active WKURLSchemeTask operations for cancellation
    private struct TaskInfo {
        let task: Task<Void, Never>
        var isStopped: Bool = false
    }

    private var activeTasks: [ObjectIdentifier: TaskInfo] = [:]

    // Allowlist of resources that can be served
    private static let allowedResources: Set<String> = [
        "structured-content.css",
        "MaterialSymbolsOutlined.woff2",
        "domUtilities.js",
        "textScanning.js",
        "popup.css",
    ]

    nonisolated func reply(for request: URLRequest) -> some AsyncSequence<URLSchemeTaskResult, any Error> {
        AsyncThrowingStream<URLSchemeTaskResult, Error> { continuation in
            let task = Task { @Sendable in
                do {
                    let results = try await Self.handleRequest(request)
                    for result in results {
                        continuation.yield(result)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private static func handleRequest(_ request: URLRequest) async throws -> [URLSchemeTaskResult] {
        guard let url = request.url else {
            logger.error("Invalid URL in request")
            return createNotFoundResponse()
        }

        logger.debug("Handling request for URL: \(url.absoluteString)")

        // Parse the URL: marureader-resource://filename.ext
        guard url.scheme == "marureader-resource",
              let host = url.host(),
              !host.isEmpty
        else {
            logger.error("Invalid marureader-resource URL format: \(url.absoluteString)")
            return createNotFoundResponse()
        }

        let filename = host

        // Check if the requested resource is in our allowlist
        guard allowedResources.contains(filename) else {
            logger.warning("Requested resource not in allowlist: \(filename)")
            return createNotFoundResponse()
        }

        let resourceURL = try bundleResourceURL(filename: filename)

        // Check if file exists
        guard (try? resourceURL.checkResourceIsReachable()) == true else {
            logger.warning("Resource file not found: \(resourceURL.path)")
            return createNotFoundResponse()
        }

        // Read file data
        let fileData: Data
        do {
            fileData = try Data(contentsOf: resourceURL)
        } catch {
            logger.error("Failed to read resource file: \(error.localizedDescription)")
            return createServerErrorResponse()
        }

        // Determine MIME type
        let mimeType = getMimeType(for: resourceURL)

        // Create HTTP response
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": mimeType,
                "Content-Length": "\(fileData.count)",
                "Cache-Control": "max-age=31536000", // Cache for 1 year since resources are immutable
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET",
                "Access-Control-Allow-Headers": "Content-Type",
            ]
        )!

        logger.debug("Serving resource file: \(resourceURL.path()) (\(fileData.count) bytes, \(mimeType))")

        return [
            .response(response),
            .data(fileData),
        ]
    }

    private static func bundleResourceURL(filename: String) throws -> URL {
        let components = filename.components(separatedBy: ".")
        let name = components.first ?? filename
        let ext = components.count > 1 ? components.last : nil

        guard let resourceURL = Bundle.main.url(forResource: name, withExtension: ext) else {
            throw NSError(domain: "ResourceURLSchemeHandler", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Resource file not found in bundle: \(filename)",
            ])
        }

        return resourceURL
    }

    private static func getMimeType(for url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()

        if let utType = UTType(filenameExtension: pathExtension) {
            return utType.preferredMIMEType ?? "application/octet-stream"
        }

        // Fallback for common resource types
        switch pathExtension {
        case "css":
            return "text/css"
        case "js":
            return "application/javascript"
        case "json":
            return "application/json"
        case "html", "htm":
            return "text/html"
        case "txt":
            return "text/plain"
        case "xml":
            return "application/xml"
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "gif":
            return "image/gif"
        case "svg":
            return "image/svg+xml"
        default:
            return "application/octet-stream"
        }
    }

    private static func createNotFoundResponse() -> [URLSchemeTaskResult] {
        let response = HTTPURLResponse(
            url: URL(string: "marureader-resource://error")!,
            statusCode: 404,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/plain"]
        )!

        let data = "Resource not found".data(using: .utf8)!

        return [
            .response(response),
            .data(data),
        ]
    }

    private static func createServerErrorResponse() -> [URLSchemeTaskResult] {
        let response = HTTPURLResponse(
            url: URL(string: "marureader-resource://error")!,
            statusCode: 500,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/plain"]
        )!

        let data = "Internal server error".data(using: .utf8)!

        return [
            .response(response),
            .data(data),
        ]
    }

    // MARK: - WKURLSchemeHandler conformance

    func webView(_: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let taskId = ObjectIdentifier(urlSchemeTask)
        let request = urlSchemeTask.request

        let task = Task { [weak self] in
            do {
                let results = try await Self.handleRequest(request)

                for result in results {
                    // Check if task was cancelled
                    if Task.isCancelled {
                        return
                    }

                    // Check if task was stopped before calling WKURLSchemeTask methods
                    let isStopped = await MainActor.run {
                        self?.activeTasks[taskId]?.isStopped ?? true
                    }
                    if isStopped {
                        return
                    }

                    await MainActor.run {
                        switch result {
                        case let .response(response):
                            urlSchemeTask.didReceive(response)
                        case let .data(data):
                            urlSchemeTask.didReceive(data)
                        @unknown default:
                            break
                        }
                    }
                }

                // Check if task was stopped before calling didFinish
                let isStopped = await MainActor.run {
                    self?.activeTasks[taskId]?.isStopped ?? true
                }
                if !isStopped {
                    await MainActor.run {
                        urlSchemeTask.didFinish()
                    }
                }
            } catch {
                // Check if task was stopped before reporting error
                let isStopped = await MainActor.run {
                    self?.activeTasks[taskId]?.isStopped ?? true
                }
                if !isStopped {
                    await MainActor.run {
                        urlSchemeTask.didFailWithError(error)
                    }
                }
            }

            // Clean up task tracking
            _ = await MainActor.run {
                self?.activeTasks.removeValue(forKey: taskId)
            }
        }

        // Store task for potential cancellation BEFORE starting async work
        activeTasks[taskId] = TaskInfo(task: task, isStopped: false)
    }

    func webView(_: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        let taskId = ObjectIdentifier(urlSchemeTask)

        // Mark task as stopped BEFORE cancelling to prevent any pending operations
        // from calling methods on the urlSchemeTask
        if var taskInfo = activeTasks[taskId] {
            taskInfo.isStopped = true
            activeTasks[taskId] = taskInfo
            taskInfo.task.cancel()
        }

        // Remove from tracking
        activeTasks.removeValue(forKey: taskId)
    }
}
