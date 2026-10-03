// WebBrowserView.swift
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

import CoreGraphics
import SwiftUI
import WebKit

struct WebBrowserView: UIViewRepresentable {
    let page: WebBrowserPage
    let chromeInsets: EdgeInsets
    let onScrollOffsetChange: (@MainActor (CGFloat, CGFloat) -> Void)?

    init(
        page: WebBrowserPage,
        chromeInsets: EdgeInsets = EdgeInsets(),
        onScrollOffsetChange: (@MainActor (CGFloat, CGFloat) -> Void)? = nil
    ) {
        self.page = page
        self.chromeInsets = chromeInsets
        self.onScrollOffsetChange = onScrollOffsetChange
    }

    func makeUIView(context _: Context) -> WKWebView {
        page.setScrollOffsetChangeHandler { oldOffset, newOffset in
            onScrollOffsetChange?(oldOffset, newOffset)
        }
        page.applyChromeInsets(top: chromeInsets.top, bottom: chromeInsets.bottom)
        return page.webView
    }

    func updateUIView(_: WKWebView, context _: Context) {
        page.setScrollOffsetChangeHandler { oldOffset, newOffset in
            onScrollOffsetChange?(oldOffset, newOffset)
        }
        page.applyChromeInsets(top: chromeInsets.top, bottom: chromeInsets.bottom)
    }

    static func dismantleUIView(_: WKWebView, coordinator _: ()) {}
}
