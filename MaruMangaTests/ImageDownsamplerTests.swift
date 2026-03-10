// ImageDownsamplerTests.swift
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

@testable import MaruManga
import Testing
import UIKit

struct ImageDownsamplerTests {
    // MARK: - downsample

    @Test func downsample_reducesLargeImage() throws {
        let data = makeImageData(width: 4000, height: 3000)

        let image = ImageDownsampler.downsample(data: data, maxPixelSize: 1000)

        let result = try #require(image)
        let maxDim = max(result.size.width, result.size.height)
        #expect(maxDim <= 1000)
        #expect(maxDim > 0)
    }

    @Test func downsample_preservesAspectRatio() throws {
        let data = makeImageData(width: 4000, height: 2000)

        let image = ImageDownsampler.downsample(data: data, maxPixelSize: 1000)

        let result = try #require(image)
        let ratio = result.size.width / result.size.height
        #expect(abs(ratio - 2.0) < 0.01)
    }

    @Test func downsample_doesNotUpscaleSmallImage() throws {
        let data = makeImageData(width: 100, height: 80)

        let image = ImageDownsampler.downsample(data: data, maxPixelSize: 1000)

        let result = try #require(image)
        #expect(result.size.width <= 100)
        #expect(result.size.height <= 80)
    }

    @Test func downsample_invalidData_returnsNil() {
        let data = Data("not an image".utf8)

        let result = ImageDownsampler.downsample(data: data, maxPixelSize: 1000)

        #expect(result == nil)
    }

    @Test func downsample_emptyData_returnsNil() {
        let result = ImageDownsampler.downsample(data: Data(), maxPixelSize: 1000)

        #expect(result == nil)
    }

    // MARK: - imagePixelSize

    @Test func imagePixelSize_returnsCorrectDimensions() {
        let data = makeImageData(width: 800, height: 600)

        let size = ImageDownsampler.imagePixelSize(data: data)

        #expect(size?.width == 800)
        #expect(size?.height == 600)
    }

    @Test func imagePixelSize_invalidData_returnsNil() {
        let data = Data("not an image".utf8)

        let size = ImageDownsampler.imagePixelSize(data: data)

        #expect(size == nil)
    }

    // MARK: - downsampledJPEGData

    @Test func downsampledJPEGData_producesValidJPEG() throws {
        let data = makeImageData(width: 2000, height: 1500)

        let jpegData = ImageDownsampler.downsampledJPEGData(data: data, maxPixelSize: 500)

        let result = try #require(jpegData)
        #expect(UIImage(data: result) != nil)
    }

    @Test func downsampledJPEGData_isDownsampled() throws {
        let data = makeImageData(width: 2000, height: 1500)

        let jpegData = ImageDownsampler.downsampledJPEGData(data: data, maxPixelSize: 500)

        let result = try #require(jpegData)
        let size = ImageDownsampler.imagePixelSize(data: result)
        let maxDim = max(size?.width ?? 0, size?.height ?? 0)
        #expect(maxDim <= 500)
    }

    @Test func downsampledJPEGData_invalidData_returnsNil() {
        let data = Data("not an image".utf8)

        let result = ImageDownsampler.downsampledJPEGData(data: data, maxPixelSize: 500)

        #expect(result == nil)
    }

    // MARK: - Helpers

    private func makeImageData(width: Int, height: Int) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: width, height: height),
            format: format
        )
        let image = renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.jpegData(compressionQuality: 0.9)!
    }
}
