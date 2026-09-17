// YouTubeVideo.swift
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

enum YouTubeVideo {
    static func isYouTube(_ url: URL?) -> Bool {
        guard let url, ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { return false }
        return ["youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be"].contains(url.host?.lowercased() ?? "")
    }

    static func id(from url: URL?) -> String? {
        guard isYouTube(url), let url else { return nil }
        let value: String? = if url.host?.lowercased() == "youtu.be" {
            url.pathComponents.dropFirst().first
        } else if url.path == "/watch" {
            URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "v" }?.value
        } else {
            nil
        }
        guard let value, !value.isEmpty,
              value.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else { return nil }
        return value
    }

    static func desktopURL(for url: URL) -> URL? {
        guard isYouTube(url), var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        if url.host?.lowercased() == "youtu.be", let videoID = id(from: url) {
            components.path = "/watch"
            components.queryItems = [URLQueryItem(name: "v", value: videoID)] + (components.queryItems ?? []).filter { $0.name != "v" }
        }
        components.host = "www.youtube.com"
        return components.url
    }
}
