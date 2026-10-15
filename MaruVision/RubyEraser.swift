// RubyEraser.swift
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

// Erases furigana beside text lines at the image level, so Vision does not
// read the ruby into the base text. Given a line's box (pixels, top-left
// origin) and direction, it binarises the band beside the line, finds the
// connected components, takes the base characters as the band of wide
// components, and paints every small component in the ruby band (right of a
// vertical column, above a horizontal line) with the background colour.

import CoreGraphics
import Foundation

public enum RubyEraser {
    /// RUBY_DEBUG=1 traces each line's decisions to stderr.
    static let debug = ProcessInfo.processInfo.environment["RUBY_DEBUG"] != nil
    static func trace(_ s: @autoclosure () -> String) {
        if debug {
            FileHandle.standardError.write(Data((s() + "\n").utf8))
        }
    }

    /// A text line to clean, in pixel coordinates with the origin top-left.
    public struct Line {
        public var box: CGRect
        public var vertical: Bool
        public init(box: CGRect, vertical: Bool) {
            self.box = box; self.vertical = vertical
        }
    }

    /// Tunables, exposed for experiments.
    public struct Options: Sendable {
        /// How far beyond the base band the ruby band may reach, in character sizes.
        public var reach: CGFloat = 0.9
        /// Components narrower than this fraction of the character size can be ruby.
        public var maxRubyWidth: CGFloat = 0.6
        /// Whether to clean horizontal lines (ruby above) as well as vertical ones.
        public var horizontal = true
        public init() {}
    }

    /// `image` with the ruby beside each line erased. Returns the image itself
    /// when nothing was erased.
    public static func erase(_ image: CGImage, lines: [Line], options: Options = Options()) -> CGImage {
        let w = image.width, h = image.height
        // The page is copied into an array rather than edited through the
        // context's pointer, so the module stays free of unsafe constructs.
        guard w > 0, h > 0, !lines.isEmpty, var pixels = rgba(image) else { return image }
        var erased = 0
        for line in lines where line.vertical || options.horizontal {
            erased += eraseLine(line, pixels: &pixels, width: w, height: h, options: options)
        }
        guard erased > 0, let provider = CGDataProvider(data: Data(pixels) as CFData),
              // `unsafe` only because the `decode` parameter is a pointer; nil is passed.
              let out = unsafe CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { return image }
        return out
    }

    /// The image's pixels as packed RGBX rows, top row first.
    static func rgba(_ image: CGImage) -> [UInt8]? {
        let w = image.width, h = image.height
        // `unsafe` only because the `data` parameter is a pointer; nil lets the context own its buffer.
        guard let context = unsafe CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = context.makeImage()?.dataProvider?.data as Data? else { return nil }
        return [UInt8](data)
    }

    /// Luminance at a pixel (rows run top to bottom).
    @inline(__always) private static func luma(_ p: [UInt8], _ i: Int) -> Int {
        (Int(p[i * 4]) * 299 + Int(p[i * 4 + 1]) * 587 + Int(p[i * 4 + 2]) * 114) / 1000
    }

    /// Cleans one line. Works in local axes: u across the line, increasing
    /// towards the ruby side; v along it. Returns the number of pixels erased.
    private static func eraseLine(_ line: Line, pixels: inout [UInt8], width: Int, height: Int,
                                  options: Options) -> Int
    {
        let box = line.box
        let t = line.vertical ? box.width : box.height // thickness, inflated when ruby is in the box
        guard t >= 6 else { trace("line \(box.integral) \(line.vertical ? "V" : "H"): too thin"); return 0 }
        // A box of one character has no ruby worth the risk: a gap inside the
        // character would split it into a band and "ruby".
        guard (line.vertical ? box.height : box.width) >= 1.5 * t else { trace("line \(box.integral): short"); return 0 }
        // Window: the box, 0.2 t into the far side, `reach` t past the ruby side, 0.4 t along.
        let far = 0.2 * t, near = (options.reach + 0.2) * t, along = 0.4 * t
        let win: CGRect = line.vertical
            ? CGRect(x: box.minX - far, y: box.minY - along, width: box.width + far + near, height: box.height + 2 * along)
            : CGRect(x: box.minX - along, y: box.minY - near, width: box.width + 2 * along, height: box.height + far + near)
        let r = win.integral.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard !r.isNull, r.width >= 4, r.height >= 4 else { return 0 }
        let x0 = Int(r.minX), y0 = Int(r.minY), rw = Int(r.width), rh = Int(r.height)
        // Local size: U across (towards ruby), V along.
        let U = line.vertical ? rw : rh, V = line.vertical ? rh : rw
        // Page pixel index for local (u, v). Horizontal lines: u grows upwards.
        @inline(__always) func index(_ u: Int, _ v: Int) -> Int {
            line.vertical ? (y0 + v) * width + x0 + u : (y0 + rh - 1 - u) * width + x0 + v
        }

        // Otsu threshold; ink is the smaller class.
        var hist = [Int](repeating: 0, count: 256)
        var lum = [UInt8](repeating: 0, count: U * V)
        for v in 0 ..< V {
            for u in 0 ..< U {
                let l = luma(pixels, index(u, v)); lum[v * U + u] = UInt8(l); hist[l] += 1
            }
        }
        let n = U * V
        var sum = 0
        for i in 0 ..< 256 {
            sum += i * hist[i]
        }
        var sumB = 0, wB = 0, best = 0.0, threshold = 128
        for i in 0 ..< 256 {
            wB += hist[i]
            guard wB > 0, wB < n else { continue }
            sumB += i * hist[i]
            let mB = Double(sumB) / Double(wB), mF = Double(sum - sumB) / Double(n - wB)
            let between = Double(wB) * Double(n - wB) * (mB - mF) * (mB - mF)
            if between > best {
                best = between; threshold = i
            }
        }
        // Flat window (no two classes) or too little contrast: nothing to do.
        let dark = hist[0 ... threshold].reduce(0, +)
        guard dark > 0, dark < n else { return 0 }
        let darkMean = (0 ... threshold).reduce(0) { $0 + $1 * hist[$1] } / dark
        let lightMean = ((threshold + 1) ..< 256).reduce(0) { $0 + $1 * hist[$1] } / (n - dark)
        guard lightMean - darkMean >= 40 else { trace("line \(box.integral): low contrast \(lightMean - darkMean)"); return 0 }
        let inkIsDark = dark <= n - dark
        var ink = [Bool](repeating: false, count: n)
        for i in 0 ..< n {
            ink[i] = (Int(lum[i]) <= threshold) == inkIsDark
        }

        // Connected components (8-connected).
        struct Component { var u0: Int, u1: Int, v0: Int, v1: Int, count: Int, pixels: [Int] }
        var label = [Int32](repeating: -1, count: n)
        var components: [Component] = []
        var stack: [Int] = []
        for start in 0 ..< n where ink[start] && label[start] < 0 {
            let id = Int32(components.count)
            var c = Component(u0: U, u1: -1, v0: V, v1: -1, count: 0, pixels: [])
            label[start] = id
            stack.append(start)
            while let i = stack.popLast() {
                let u = i % U, v = i / U
                c.u0 = min(c.u0, u); c.u1 = max(c.u1, u); c.v0 = min(c.v0, v); c.v1 = max(c.v1, v)
                c.count += 1
                c.pixels.append(i)
                for dv in -1 ... 1 {
                    for du in -1 ... 1 {
                        let nu = u + du, nv = v + dv
                        guard nu >= 0, nu < U, nv >= 0, nv < V else { continue }
                        let j = nv * U + nu
                        if ink[j], label[j] < 0 {
                            label[j] = id; stack.append(j)
                        }
                    }
                }
            }
            components.append(c)
        }
        // Base band from the ink profile across the line, over the box's own
        // length: the run of columns with ink that overlaps the box most. The
        // gap between base text and ruby is a dip to nothing in the profile.
        let alongPad = Int(along)
        let v0 = max(0, alongPad), v1 = min(V, V - alongPad)
        guard v1 > v0 else { return 0 }
        var profile = [Int](repeating: 0, count: U)
        for v in v0 ..< v1 {
            for u in 0 ..< U where ink[v * U + u] {
                profile[u] += 1
            }
        }
        let peak = profile.max() ?? 0
        let threshold2 = max(2, peak / 10)
        var segments: [(u0: Int, u1: Int)] = []
        var u = 0
        while u < U {
            if profile[u] >= threshold2 {
                var end = u
                while end + 1 < U, profile[end + 1] >= threshold2 {
                    end += 1
                }
                segments.append((u, end))
                u = end + 1
            } else {
                u += 1
            }
        }
        // The box's own extent across the window.
        let b0 = Int(line.vertical ? box.minX - r.minX : r.maxY - box.maxY), b1 = b0 + Int(t)
        guard var band = segments.max(by: { a, b in
            let oa = min(a.u1, b1) - max(a.u0, b0), ob = min(b.u1, b1) - max(b.u0, b0)
            return oa != ob ? oa < ob : (a.u1 - a.u0) < (b.u1 - b.u0)
        }) else { trace("line \(box.integral): no ink"); return 0 }
        // Grow the band to the first blank columns, so dakuten and thin
        // strokes at the edge of the cell stay in it. Ruby is separated from
        // its base by at least one blank column.
        // Growth is bounded, so speckle on a dark background cannot join
        // two columns into one band.
        let grow = max(2, threshold2 / 3), maxGrow = (band.u1 - band.u0 + 1) / 5
        var grown = 0
        // Growth never enters another segment.
        while band.u0 > 0, profile[band.u0 - 1] >= grow, profile[band.u0 - 1] < threshold2, grown < maxGrow {
            band.u0 -= 1; grown += 1
        }
        grown = 0
        while band.u1 + 1 < U, profile[band.u1 + 1] >= grow, profile[band.u1 + 1] < threshold2, grown < maxGrow {
            band.u1 += 1; grown += 1
        }
        let e = CGFloat(band.u1 - band.u0 + 1)
        trace("line \(box.integral) \(line.vertical ? "V" : "H"): t \(t) e \(e) U \(U) band u \(band.u0)-\(band.u1) segments \(segments.map { "\($0.u0)-\($0.u1)" })")
        // A band much narrower than the box is a stroke of one character or
        // noise; one wider than it has swallowed a neighbour.
        guard e >= 0.4 * t, e <= 1.1 * t else { trace("  band off"); return 0 }

        // Ruby: small components entirely past the band, within reach, beside
        // the band along the line, and not clipped by the window edge.
        var reachU = CGFloat(band.u1) + options.reach * e
        // A segment past the band as wide as a character is the next column,
        // not ruby: nothing beyond its start is erased.
        if let next = segments.first(where: { $0.u1 > band.u1 && CGFloat($0.u1 - $0.u0 + 1) >= options.maxRubyWidth * e }) {
            reachU = min(reachU, CGFloat(next.u0 - 1))
        }
        let vPad = Int(0.5 * e)
        var erasedPixels: [Int] = []
        // Specks under 5 px are halftone dots: erasing them leaves a stripe.
        for c in components where c.u0 > band.u1 && c.count >= 5 {
            let ok = CGFloat(c.u1) <= reachU && c.u1 < U - 1 && CGFloat(c.u1 - c.u0 + 1) < options.maxRubyWidth * e
                && c.v1 >= v0 - vPad && c.v0 <= v1 + vPad
            if ok {
                erasedPixels += c.pixels
            }
            if c.count >= 4 {
                trace("  comp u \(c.u0)-\(c.u1) v \(c.v0)-\(c.v1) n \(c.count) \(ok ? "erase" : "keep")")
            }
        }
        guard !erasedPixels.isEmpty else { return 0 }
        // Ruby runs along the line; a dakuten past the cell edge is one spot.
        var cover = 0
        var covered = [Bool](repeating: false, count: V)
        for i in erasedPixels where !covered[i / U] {
            covered[i / U] = true; cover += 1
        }
        guard CGFloat(cover) >= 0.45 * e else { trace("  only \(cover) rows past the band, kept"); return 0 }

        // Background colour: mean of the non-ink pixels in the window.
        var bg = [0, 0, 0], count = 0
        for v in 0 ..< V {
            for u in 0 ..< U where !ink[v * U + u] {
                let i = index(u, v) * 4
                bg[0] += Int(pixels[i]); bg[1] += Int(pixels[i + 1]); bg[2] += Int(pixels[i + 2]); count += 1
            }
        }
        guard count > 0 else { return 0 }
        let fill = bg.map { UInt8($0 / count) }
        // Paint the components and a one-pixel halo (anti-aliased edges).
        var painted = 0
        for i in erasedPixels {
            let u = i % U, v = i / U
            for dv in -1 ... 1 {
                for du in -1 ... 1 {
                    let nu = u + du, nv = v + dv
                    guard nu >= 0, nu < U, nv >= 0, nv < V else { continue }
                    let p = index(nu, nv) * 4
                    pixels[p] = fill[0]; pixels[p + 1] = fill[1]; pixels[p + 2] = fill[2]
                    painted += 1
                }
            }
        }
        return painted
    }
}
