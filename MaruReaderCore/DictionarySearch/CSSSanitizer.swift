// CSSSanitizer.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import Foundation

/// Sanitizes CSS content from dictionary stylesheets to prevent script injection attacks.
///
/// This addresses the vulnerability described in GHSA-g3p8-q34q-x686, where malicious
/// stylesheets can break out of `<style>` tags and inject arbitrary HTML/JavaScript.
///
/// The sanitizer removes:
/// - HTML tags (especially `</style>` and `<script>`)
/// - JavaScript URLs in CSS
/// - Legacy IE expression() functions
/// - HTML comment markers that could interfere with parsing
public enum CSSSanitizer {
    /// Sanitizes CSS content by removing potentially dangerous patterns.
    ///
    /// - Parameter css: Raw CSS content from a dictionary stylesheet.
    /// - Returns: Sanitized CSS safe for inclusion in a `<style>` tag.
    public static func sanitize(_ css: String) -> String {
        var result = css

        // First, remove entire script blocks including their content
        // This handles <script>...</script> and variations
        result = result.replacingOccurrences(
            of: "<\\s*script[^>]*>[\\s\\S]*?<\\s*/\\s*script\\s*>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Remove HTML tags - especially </style> and <script> which enable XSS
        // This regex matches any HTML tag: < followed by optional /, tag name, attributes, and >
        // Case insensitive to catch </STYLE>, </Style>, <SCRIPT>, etc.
        result = result.replacingOccurrences(
            of: "<\\s*/?\\s*[a-zA-Z][^>]*>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Remove javascript: URLs (case insensitive, allowing whitespace)
        // These can appear in url() functions
        result = result.replacingOccurrences(
            of: "javascript\\s*:",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Remove vbscript: URLs (legacy IE attack vector)
        result = result.replacingOccurrences(
            of: "vbscript\\s*:",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Remove data: URLs that could contain scripts (data:text/html, etc.)
        // Keep data:image/* URLs as they're commonly used for inline images
        result = result.replacingOccurrences(
            of: "data\\s*:\\s*(?!image/)[^;,)\\s]+",
            with: "data:blocked",
            options: [.regularExpression, .caseInsensitive]
        )

        // Remove IE expression() which can execute JavaScript
        result = result.replacingOccurrences(
            of: "expression\\s*\\(",
            with: "blocked(",
            options: [.regularExpression, .caseInsensitive]
        )

        // Remove -moz-binding which can load XBL (XML Binding Language) with scripts
        result = result.replacingOccurrences(
            of: "-moz-binding\\s*:",
            with: "-blocked-binding:",
            options: [.regularExpression, .caseInsensitive]
        )

        // Remove behavior: which is IE-specific and can load HTC files with scripts
        result = result.replacingOccurrences(
            of: "behavior\\s*:",
            with: "blocked:",
            options: [.regularExpression, .caseInsensitive]
        )

        // Remove HTML comment markers which could interfere with HTML parsing
        result = result.replacingOccurrences(of: "<!--", with: "")
        result = result.replacingOccurrences(of: "-->", with: "")

        return result
    }
}
