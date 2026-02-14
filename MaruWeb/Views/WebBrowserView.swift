// WebBrowserView.swift
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

import CoreGraphics
import SwiftUI
import WebKit

struct WebBrowserView: UIViewRepresentable {
    let page: WebBrowserPage
    let onScrollOffsetChange: (@MainActor (CGFloat, CGFloat) -> Void)?

    init(
        page: WebBrowserPage,
        onScrollOffsetChange: (@MainActor (CGFloat, CGFloat) -> Void)? = nil
    ) {
        self.page = page
        self.onScrollOffsetChange = onScrollOffsetChange
    }

    func makeUIView(context _: Context) -> WKWebView {
        page.setScrollOffsetChangeHandler { oldOffset, newOffset in
            onScrollOffsetChange?(oldOffset, newOffset)
        }
        return page.webView
    }

    func updateUIView(_: WKWebView, context _: Context) {
        page.setScrollOffsetChangeHandler { oldOffset, newOffset in
            onScrollOffsetChange?(oldOffset, newOffset)
        }
    }

    static func dismantleUIView(_: WKWebView, coordinator _: ()) {}
}
