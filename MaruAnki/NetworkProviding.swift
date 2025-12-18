//
//  NetworkProviding.swift
//  MaruReader
//
//  Created by Sam Smoker on 12/18/25.
//

import Foundation

/// A protocol abstracting network data fetching for dependency injection.
///
/// This allows injecting mock network providers in tests to capture requests
/// and return canned responses without hitting the network.
protocol NetworkProviding: Sendable {
    /// Fetches data for the given request.
    ///
    /// - Parameter request: The URL request to execute.
    /// - Returns: A tuple containing the response data and URL response.
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: NetworkProviding {}
