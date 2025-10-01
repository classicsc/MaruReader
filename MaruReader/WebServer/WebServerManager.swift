//
//  WebServerManager.swift
//  MaruReader
//
//  Manages GCDWebServer instances for serving dictionary content via HTTP.
//

import Foundation
import os.log
@unsafe @preconcurrency import ReadiumGCDWebServer

/// Manages a GCDWebServer instance with automatic port allocation and lifecycle management
@MainActor
class WebServerManager {
    private static let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "WebServerManager")

    private var server: ReadiumGCDWebServer?
    private var assignedPort: UInt = 0

    /// Base URL for the server (e.g., "http://localhost:8080")
    var baseURL: URL? {
        guard let port = server?.port, port > 0 else { return nil }
        return URL(string: "http://localhost:\(port)")
    }

    /// Whether the server is currently running
    var isRunning: Bool {
        server?.isRunning ?? false
    }

    init() {}

    /// Starts the server with the provided route handlers
    /// - Returns: True if server started successfully
    func start() -> Bool {
        guard server == nil else {
            Self.logger.warning("Server already running")
            return true
        }

        let newServer = ReadiumGCDWebServer()

        // Configure server options
        let options: [String: Any] = [
            ReadiumGCDWebServerOption_Port: 0, // Auto-assign port
            ReadiumGCDWebServerOption_BindToLocalhost: true, // Security: localhost only
            ReadiumGCDWebServerOption_ServerName: "MaruReader",
            ReadiumGCDWebServerOption_AutomaticallySuspendInBackground: false,
        ]

        do {
            try newServer.start(options: options)
        } catch {
            Self.logger.error("Failed to start web server: \(error.localizedDescription)")
            return false
        }

        server = newServer
        assignedPort = newServer.port

        Self.logger.info("Web server started on port \(self.assignedPort)")
        return true
    }

    /// Stops the server
    func stop() {
        guard let server else { return }

        server.stop()
        self.server = nil
        Self.logger.info("Web server stopped (was on port \(self.assignedPort))")
        assignedPort = 0
    }

    /// Adds a handler for a specific HTTP path
    /// - Parameters:
    ///   - method: HTTP method (GET, POST, etc.)
    ///   - path: URL path pattern
    ///   - handler: Block to process the request and return a response
    func addHandler(
        forMethod method: String,
        path: String,
        handler: @escaping (ReadiumGCDWebServerRequest) -> ReadiumGCDWebServerResponse?
    ) {
        guard let server else {
            Self.logger.error("Cannot add handler - server not initialized")
            return
        }

        server.addHandler(
            forMethod: method,
            path: path,
            request: ReadiumGCDWebServerRequest.self
        ) { request in
            handler(request)
        }
    }

    /// Adds a handler with custom matching logic
    /// - Parameters:
    ///   - matchBlock: Block to determine if this handler should process the request
    ///   - processBlock: Block to process the request and return a response
    func addHandler(
        matchBlock: @escaping ReadiumGCDWebServerMatchBlock,
        processBlock: @escaping ReadiumGCDWebServerProcessBlock
    ) {
        guard let server else {
            Self.logger.error("Cannot add handler - server not initialized")
            return
        }

        server.addHandler(match: matchBlock, processBlock: processBlock)
    }

    /// Adds an async handler with custom matching logic
    /// - Parameters:
    ///   - matchBlock: Block to determine if this handler should process the request
    ///   - asyncProcessBlock: Async block to process the request and return a response
    func addAsyncHandler(
        matchBlock: @escaping ReadiumGCDWebServerMatchBlock,
        asyncProcessBlock: @escaping ReadiumGCDWebServerAsyncProcessBlock
    ) {
        guard let server else {
            Self.logger.error("Cannot add handler - server not initialized")
            return
        }

        server.addHandler(match: matchBlock, asyncProcessBlock: asyncProcessBlock)
    }

    deinit {
        server?.stop()
    }
}
