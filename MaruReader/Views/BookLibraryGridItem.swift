// BookLibraryGridItem.swift
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

import ImageIO
import SwiftUI
import UIKit

private let bookLibraryThumbnailMaxPixelSize: CGFloat = 360

struct BookLibraryGridItem: View {
    let snapshot: BookLibrarySnapshot
    let coverImageLoader: BookLibraryCoverImageLoader
    let onCancel: () -> Void
    let onRemove: () -> Void

    @State private var coverImage: UIImage?

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Group {
                if let coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "book.closed")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(.secondary)
                        .padding(30)
                }
            }
            .frame(width: 120, height: 180)
            .background(Color(.systemGray5))
            .clipShape(.rect(cornerRadius: 8))
            .shadow(radius: 2)

            VStack(alignment: .center, spacing: 2) {
                Text(snapshot.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if let author = snapshot.author {
                    Text(author)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let progressPercent = snapshot.progressPercent {
                    Text(AppLocalization.percentRead(progressPercent))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let statusMessage = snapshot.statusMessage {
                    Text(statusMessage)
                        .font(.caption2)
                        .foregroundStyle(snapshot.status == .failed ? .red : .secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: 120)

            if let actionLabel = snapshot.actionLabel {
                Button(actionLabel) {
                    switch snapshot.status {
                    case .inProgress:
                        onCancel()
                    case .failed, .cancelled:
                        onRemove()
                    case .complete:
                        break
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .contentShape(Rectangle())
        .task(id: snapshot.coverFileName) {
            coverImage = await coverImageLoader.image(for: snapshot.coverFileName)
        }
    }
}

@MainActor
final class BookLibraryCoverImageLoader {
    private let cache = NSCache<NSURL, UIImage>()

    func image(for coverFileName: String?) async -> UIImage? {
        guard let coverURL = bookLibraryCoverURL(for: coverFileName) else { return nil }

        if let cachedImage = cache.object(forKey: coverURL as NSURL) {
            return cachedImage
        }

        let image = await Task.detached(priority: .utility) {
            loadBookLibraryImage(at: coverURL)
        }.value

        if let image {
            cache.setObject(image, forKey: coverURL as NSURL)
        }

        return image
    }
}

private func bookLibraryCoverURL(for coverFileName: String?) -> URL? {
    guard let coverFileName else { return nil }
    guard let appSupportDir = try? FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: false
    ) else {
        return nil
    }

    return appSupportDir
        .appendingPathComponent("Covers")
        .appendingPathComponent(coverFileName)
}

private func loadBookLibraryImage(at coverURL: URL) -> UIImage? {
    let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
    guard let source = CGImageSourceCreateWithURL(coverURL as CFURL, sourceOptions as CFDictionary) else {
        return nil
    }

    let downsampleOptions: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: bookLibraryThumbnailMaxPixelSize,
    ]

    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
        return nil
    }

    return UIImage(cgImage: cgImage)
}
