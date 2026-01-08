//
//  MangaArchive+FileURLs.swift
//  MaruManga
//

import CoreData
import Foundation

extension MangaArchive {
    /// Reconstructs the full URL for the manga archive file.
    /// Returns nil if localFileName is not set or if the directory cannot be resolved.
    var localPath: URL? {
        guard let fileName = localFileName else { return nil }
        return Self.mangaDirectory()?.appendingPathComponent(fileName)
    }

    /// Reconstructs the full URL for the cover image.
    /// Returns nil if coverFileName is not set or if the directory cannot be resolved.
    var coverImage: URL? {
        guard let fileName = coverFileName else { return nil }
        return Self.coversDirectory()?.appendingPathComponent(fileName)
    }

    /// Returns the Manga directory URL in the Documents directory.
    static func mangaDirectory() -> URL? {
        guard let documentsDir = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        return documentsDir.appendingPathComponent("Manga")
    }

    /// Returns the Covers directory URL in Application Support.
    static func coversDirectory() -> URL? {
        guard let appSupportDir = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        return appSupportDir.appendingPathComponent("Covers")
    }
}
