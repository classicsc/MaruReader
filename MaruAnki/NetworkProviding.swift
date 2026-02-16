// NetworkProviding.swift
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
