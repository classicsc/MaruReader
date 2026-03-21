// MangaLibraryGridItem.swift
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

private let mangaLibraryThumbnailMaxPixelSize: CGFloat = 360

struct MangaLibraryGridItem: View {
    let snapshot: MangaLibrarySnapshot
    let coverImageLoader: MangaLibraryCoverImageLoader
    let onCancel: () -> Void
    let onRemove: () -> Void

    @State private var coverImage: UIImage?

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Group {
                if let coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
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

                if let progressText = snapshot.progressText {
                    Text(progressText)
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
final class MangaLibraryCoverImageLoader {
    private let cache = NSCache<NSURL, UIImage>()

    func image(for coverFileName: String?) async -> UIImage? {
        guard let coverURL = mangaLibraryCoverURL(for: coverFileName) else { return nil }

        if let cachedImage = cache.object(forKey: coverURL as NSURL) {
            return cachedImage
        }

        let image = await Task.detached(priority: .utility) {
            loadMangaLibraryImage(at: coverURL)
        }.value

        if let image {
            cache.setObject(image, forKey: coverURL as NSURL)
        }

        return image
    }
}

private func mangaLibraryCoverURL(for coverFileName: String?) -> URL? {
    guard let coverFileName else { return nil }
    return MangaArchive.coversDirectory()?.appendingPathComponent(coverFileName)
}

private func loadMangaLibraryImage(at coverURL: URL) -> UIImage? {
    let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
    guard let source = CGImageSourceCreateWithURL(coverURL as CFURL, sourceOptions as CFDictionary) else {
        return nil
    }

    let downsampleOptions: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: mangaLibraryThumbnailMaxPixelSize,
    ]

    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
        return nil
    }

    return UIImage(cgImage: cgImage)
}
