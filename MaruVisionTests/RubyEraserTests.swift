// RubyEraserTests.swift
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
@testable import MaruVision
import Testing

/// A white page with a column of 24 px black squares at x 40–64 and, when
/// `ruby` is set, two 10 px squares beside each one at x 72–82.
private func page(ruby: Bool) -> CGImage {
    let ctx = unsafe CGContext(data: nil, width: 160, height: 240, bitsPerComponent: 8, bytesPerRow: 0,
                               space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: 160, height: 240))
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    for i in 0 ..< 5 {
        ctx.fill(CGRect(x: 40, y: 20 + i * 40, width: 24, height: 24))
        if ruby {
            ctx.fill(CGRect(x: 72, y: 20 + i * 40, width: 10, height: 10))
            ctx.fill(CGRect(x: 72, y: 34 + i * 40, width: 10, height: 10))
        }
    }
    return ctx.makeImage()!
}

/// Red channel at (x, y), with y from the bottom as `page` draws.
private func luma(_ image: CGImage, x: Int, y: Int) -> Int {
    let pixels = RubyEraser.rgba(image)!
    let row = image.height - 1 - y
    return Int(pixels[(row * image.width + x) * 4])
}

struct RubyEraserTests {
    @Test func erasesRubyBesideColumn() {
        // The line box covers the column and its ruby, as Vision's does when it merges them.
        let line = RubyEraser.Line(box: CGRect(x: 38, y: 18, width: 46, height: 190), vertical: true)
        let out = RubyEraser.erase(page(ruby: true), lines: [line])
        #expect(luma(out, x: 77, y: 25) > 200, "ruby erased")
        #expect(luma(out, x: 77, y: 199) > 200, "last ruby erased")
        #expect(luma(out, x: 52, y: 32) < 50, "base character kept")
    }

    @Test func returnsSameImageWhenNothingErased() {
        let line = RubyEraser.Line(box: CGRect(x: 38, y: 18, width: 28, height: 190), vertical: true)
        let input = page(ruby: false)
        #expect(RubyEraser.erase(input, lines: [line]) === input)
    }

    @Test func pixelRectFlipsToTopLeftOrigin() {
        let box = CGRect(x: 0.25, y: 0.5, width: 0.5, height: 0.25)
        #expect(pixelRect(box, in: page(ruby: false)) == CGRect(x: 40, y: 60, width: 80, height: 60))
    }
}
