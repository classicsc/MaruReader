import Foundation

/// Supported dictionary index formats.
enum DictionaryFormat: Int, Codable, Sendable, CustomStringConvertible {
    case v1 = 1
    case v3 = 3

    var description: String { "v\(rawValue)" }

    /// Derive a format from optional "format" and legacy "version" fields.
    /// Order of precedence matches existing logic: explicit format, then version.
    static func resolve(format: Int?, version: Int?) throws -> DictionaryFormat {
        if let f = format, let fmt = DictionaryFormat(rawValue: f) { return fmt }
        if let v = version, let fmt = DictionaryFormat(rawValue: v) { return fmt }
        throw DictionaryImportError.unsupportedFormat
    }
}
