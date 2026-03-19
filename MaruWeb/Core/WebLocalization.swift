// WebLocalization.swift
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

private final class WebBundleFinder {}

enum WebLocalization {
    static let bundle: Bundle = .init(for: WebBundleFinder.self)

    static func string(
        _ keyAndValue: String,
        locale: Locale = .current,
        comment _: StaticString? = nil
    ) -> String {
        bundle.localizedString(forKey: keyAndValue, value: keyAndValue, table: nil, localizations: [locale.language])
    }

    static func string(
        _ key: String,
        defaultValue: String,
        locale: Locale = .current,
        comment _: StaticString? = nil
    ) -> String {
        bundle.localizedString(forKey: key, value: defaultValue, table: nil, localizations: [locale.language])
    }
}

enum WebStrings {
    private static let titleToken = "__TITLE__"
    private static let urlToken = "__URL__"

    static func untitledBookmark(locale: Locale = .current) -> String {
        WebLocalization.string("Untitled Bookmark", locale: locale, comment: "Fallback title for a bookmark with no title and no usable URL host.")
    }

    static func newTab(locale: Locale = .current) -> String {
        WebLocalization.string("New Tab", locale: locale, comment: "Fallback title for a blank web browser tab.")
    }

    static func webViewer(locale: Locale = .current) -> String {
        WebLocalization.string("Web Viewer", locale: locale, comment: "Fallback title shown for the web viewer when there is no current URL or page title.")
    }

    static func webPage(locale: Locale = .current) -> String {
        WebLocalization.string("Web page", locale: locale, comment: "Fallback context title used when a webpage has no document title.")
    }

    static func unknownURL(locale: Locale = .current) -> String {
        WebLocalization.string("Unknown URL", locale: locale, comment: "Fallback context value used when a webpage URL is unavailable.")
    }

    static func contextInfo(title: String, urlString: String, locale: Locale = .current) -> String {
        let template = WebLocalization.string(
            "web.contextInfo.format",
            defaultValue: "\(titleToken) - \(urlToken)",
            locale: locale,
            comment: "Format for web lookup context info. The first argument is the webpage title and the second is the URL."
        )
        return template
            .replacingOccurrences(of: titleToken, with: title)
            .replacingOccurrences(of: urlToken, with: urlString)
    }

    static func searchEngineDisplayName(_ kind: SearchEngineKind, locale: Locale = .current) -> String {
        switch kind {
        case .google:
            WebLocalization.string("Google", locale: locale, comment: "Display name for the Google search engine option.")
        case .bing:
            WebLocalization.string("Bing", locale: locale, comment: "Display name for the Bing search engine option.")
        case .custom:
            WebLocalization.string("Custom", locale: locale, comment: "Display name for the custom search engine option.")
        }
    }

    static func addressBarTourTitle(locale: Locale = .current) -> String {
        WebLocalization.string("Address Bar", locale: locale, comment: "Title of the web viewer tour step that explains the address bar.")
    }

    static func addressBarTourDescription(locale: Locale = .current) -> String {
        WebLocalization.string(
            "Tap to edit the URL or see the current site.",
            locale: locale,
            comment: "Description of the web viewer tour step that explains the address bar."
        )
    }

    static func bookmarksTourDescription(locale: Locale = .current) -> String {
        WebLocalization.string(
            "Tap to add or remove bookmarks and jump to saved pages.",
            locale: locale,
            comment: "Description of the web viewer tour step that explains bookmarks."
        )
    }

    static func dismissTourDescription(locale: Locale = .current) -> String {
        WebLocalization.string(
            "Tap the more actions menu, then tap Exit Web Viewer to close and return to the app.",
            locale: locale,
            comment: "Description of the web viewer tour step that explains how to exit the web viewer."
        )
    }

    static func ocrModeTourTitle(locale: Locale = .current) -> String {
        WebLocalization.string("OCR Mode", locale: locale, comment: "Title of the web viewer tour step that explains OCR mode.")
    }

    static func ocrModeTourDescription(locale: Locale = .current) -> String {
        WebLocalization.string(
            "Enable tap-to-look-up mode for dictionary lookups on visible text.",
            locale: locale,
            comment: "Description of the web viewer tour step that explains OCR mode."
        )
    }

    static func ocrDecodeFailure(locale: Locale = .current) -> String {
        WebLocalization.string(
            "OCR capture failed to decode the image.",
            locale: locale,
            comment: "Error shown when the captured OCR image data cannot be decoded into an image."
        )
    }
}
