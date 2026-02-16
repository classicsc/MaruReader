// CoreDataTransformers.swift
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

import CoreData
import Foundation
import ReadiumNavigator

// MARK: - Transformer Names

extension NSValueTransformerName {
    static let readiumColorTransformer = NSValueTransformerName("ReadiumColorTransformer")
    static let readingProgressionTransformer = NSValueTransformerName("ReadingProgressionTransformer")
    static let imageFilterTransformer = NSValueTransformerName("ImageFilterTransformer")
}

// MARK: - Registration Helper

enum CoreDataTransformers {
    static func register() {
        // Idempotent registration (setValueTransformer replaces any existing one with same name)
        ValueTransformer.setValueTransformer(ReadiumColorTransformer(), forName: .readiumColorTransformer)
        ValueTransformer.setValueTransformer(ReadingProgressionTransformer(), forName: .readingProgressionTransformer)
        ValueTransformer.setValueTransformer(ImageFilterTransformer(), forName: .imageFilterTransformer)
    }
}

// MARK: - Base JSON Transformer

class JSONValueTransformer<Input: Codable>: ValueTransformer {
    override class func allowsReverseTransformation() -> Bool {
        true
    }

    override class func transformedValueClass() -> AnyClass {
        NSData.self
    }

    private let encoder: JSONEncoder = .init()
    // Stable key ordering not guaranteed but fine for persistence; pretty printing unnecessary

    private let decoder = JSONDecoder()

    override func transformedValue(_ value: Any?) -> Any? {
        guard let typed = value as? Input else { return nil }
        do { return try encoder.encode(typed) } catch { return nil }
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        do { return try decoder.decode(Input.self, from: data) } catch { return nil }
    }
}

// MARK: - Readium Type Transformers

final class ReadiumColorTransformer: JSONValueTransformer<ReadiumNavigator.Color> {
    // Nothing extra needed; subclass exists to provide unique name
}

final class ReadingProgressionTransformer: JSONValueTransformer<ReadiumNavigator.ReadingProgression> {
    // Nothing extra needed; subclass exists to provide unique name
}

final class ImageFilterTransformer: JSONValueTransformer<ReadiumNavigator.ImageFilter> {
    // Nothing extra needed; subclass exists to provide unique name
}
