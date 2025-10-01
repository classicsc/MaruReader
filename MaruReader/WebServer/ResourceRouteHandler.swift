//
//  ResourceRouteHandler.swift
//  MaruReader
//
//  Route handler for serving app bundle resources via HTTP.
//  Replaces ResourceURLSchemeHandler.
//

import Foundation
import os.log
import ReadiumGCDWebServer
import UniformTypeIdentifiers

/// Handles HTTP requests for app bundle resources (CSS, JS, fonts, etc.)
/// Route pattern: /resources/{filename}
class ResourceRouteHandler {
    private static let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "ResourceRouteHandler")

    // Allowlist of resources that can be served
    private static let allowedResources: Set<String> = [
        "structured-content.css",
        "MaterialSymbolsOutlined.woff2",
        "domUtilities.js",
        "textScanning.js",
        "popup.js",
        "popup.css",
        "dictionary-search.css",
    ]

    /// Registers the resource route handler with the server manager
    @MainActor
    static func register(with manager: WebServerManager) {
        manager.addHandler(
            matchBlock: { method, url, _, urlPath, _ in
                // Match GET requests to /resources/*
                guard method == "GET",
                      urlPath.hasPrefix("/resources/")
                else {
                    return nil
                }
                return ReadiumGCDWebServerRequest(method: method, url: url, headers: [:], path: urlPath, query: [:])
            },
            processBlock: { request in
                Self.handleRequest(request)
            }
        )
    }

    private static func handleRequest(_ request: ReadiumGCDWebServerRequest) -> ReadiumGCDWebServerResponse? {
        let urlPath = request.path
        logger.info("Handling resource request: \(urlPath)")

        // Parse path: /resources/{filename}
        let components = urlPath.split(separator: "/").map(String.init)
        guard components.count == 2,
              components[0] == "resources"
        else {
            logger.error("Invalid resource URL format: \(urlPath)")
            return createNotFoundResponse()
        }

        let filename = components[1]

        // Check if the requested resource is in our allowlist
        guard allowedResources.contains(filename) else {
            logger.warning("Requested resource not in allowlist: \(filename)")
            return createNotFoundResponse()
        }

        do {
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

            logger.debug("Serving resource file: \(resourceURL.path()) (\(fileData.count) bytes, \(mimeType))")

            // Create response with CORS headers
            let response = ReadiumGCDWebServerDataResponse(data: fileData, contentType: mimeType)
            response.cacheControlMaxAge = 31_536_000 // Cache for 1 year
            response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
            response.setValue("GET", forAdditionalHeader: "Access-Control-Allow-Methods")
            response.setValue("Content-Type", forAdditionalHeader: "Access-Control-Allow-Headers")
            return response

        } catch {
            logger.error("Error handling resource request: \(error.localizedDescription)")
            return createServerErrorResponse()
        }
    }

    private static func bundleResourceURL(filename: String) throws -> URL {
        let components = filename.components(separatedBy: ".")
        let name = components.first ?? filename
        let ext = components.count > 1 ? components.last : nil

        guard let resourceURL = Bundle.main.url(forResource: name, withExtension: ext) else {
            throw NSError(domain: "ResourceRouteHandler", code: 404, userInfo: [
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
        case "woff2":
            return "font/woff2"
        default:
            return "application/octet-stream"
        }
    }

    private static func createNotFoundResponse() -> ReadiumGCDWebServerResponse {
        ReadiumGCDWebServerDataResponse(
            data: "Resource not found".data(using: .utf8)!,
            contentType: "text/plain"
        )
    }

    private static func createServerErrorResponse() -> ReadiumGCDWebServerResponse {
        let response = ReadiumGCDWebServerDataResponse(
            data: "Internal server error".data(using: .utf8)!,
            contentType: "text/plain"
        )
        response.statusCode = 500
        return response
    }
}
