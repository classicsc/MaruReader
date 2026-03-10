// ImageDownsampler.swift
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
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Decodes images at a target size using ImageIO, avoiding full-resolution bitmap allocation.
enum ImageDownsampler {
    /// Decodes image data at a reduced resolution, never materializing the full-resolution bitmap.
    ///
    /// Uses `CGImageSourceCreateThumbnailAtIndex` to decode directly at the target size.
    /// If the image's longest dimension is already at or below `maxPixelSize`, it is decoded
    /// at its original size (no upscaling).
    ///
    /// - Parameters:
    ///   - data: The raw image data (JPEG, PNG, etc.).
    ///   - maxPixelSize: The maximum pixel dimension for the longest side.
    /// - Returns: A `UIImage` decoded at the target size, or `nil` if the data is invalid.
    static func downsample(data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
            return nil
        }

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    /// Returns the pixel dimensions of an image without decoding it.
    ///
    /// - Parameter data: The raw image data.
    /// - Returns: The pixel dimensions, or `nil` if the data cannot be read.
    static func imagePixelSize(data: Data) -> CGSize? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else {
            return nil
        }
        return CGSize(width: width, height: height)
    }

    /// Downsamples image data and re-encodes as JPEG.
    ///
    /// Useful for passing a smaller image to OCR or other processing steps
    /// that accept raw `Data` rather than a `UIImage`.
    ///
    /// - Parameters:
    ///   - data: The raw image data.
    ///   - maxPixelSize: The maximum pixel dimension for the longest side.
    ///   - quality: JPEG compression quality (0.0–1.0).
    /// - Returns: JPEG-encoded `Data` at the reduced resolution, or `nil` on failure.
    static func downsampledJPEGData(data: Data, maxPixelSize: CGFloat, quality: CGFloat = 0.85) -> Data? {
        guard let image = downsample(data: data, maxPixelSize: maxPixelSize),
              let cgImage = image.cgImage
        else {
            return nil
        }

        let outputData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            outputData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: max(0, min(1, quality)),
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return outputData as Data
    }
}
