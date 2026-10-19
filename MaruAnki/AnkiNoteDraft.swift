// AnkiNoteDraft.swift
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

import Foundation

/// One template value in a field, together with the value it resolved to.
/// The resolved value can be replaced by the editor without changing the template.
public struct AnkiNoteDraftValue: Identifiable, Sendable, Equatable {
    public let id: UUID
    public var template: TemplateValue
    public var resolved: TemplateResolvedValue

    public init(template: TemplateValue, resolved: TemplateResolvedValue) {
        id = UUID()
        self.template = template
        self.resolved = resolved
    }
}

/// A note field with its values in order, plus the values as they were first resolved.
public struct AnkiNoteDraftField: Identifiable, Sendable, Equatable {
    public let name: String
    public var values: [AnkiNoteDraftValue]
    public let originalValues: [AnkiNoteDraftValue]

    public var id: String {
        name
    }

    public var isEdited: Bool {
        values != originalValues
    }

    public init(name: String, values: [AnkiNoteDraftValue]) {
        self.name = name
        self.values = values
        originalValues = values
    }

    public mutating func restore() {
        values = originalValues
    }
}

/// An editable, fully resolved note. Fields are kept in name order because the field map has no order of its own.
public struct AnkiNoteDraft: Sendable, Equatable {
    public var fields: [AnkiNoteDraftField]

    public init(fields: [AnkiNoteDraftField]) {
        self.fields = fields
    }

    /// Resolves every value of the field map, the same way a direct add does.
    public static func resolve(fieldMap: AnkiFieldMap, resolver: any TemplateValueResolver) async -> AnkiNoteDraft {
        var fields: [AnkiNoteDraftField] = []
        for (name, templates) in fieldMap.map {
            var values: [AnkiNoteDraftValue] = []
            for template in templates {
                await values.append(AnkiNoteDraftValue(template: template, resolved: resolver.resolve(template)))
            }
            fields.append(AnkiNoteDraftField(name: name, values: values))
        }
        fields.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return AnkiNoteDraft(fields: fields)
    }

    /// The fields in the shape the providers consume.
    public var resolvedFields: [String: [TemplateResolvedValue]] {
        Dictionary(uniqueKeysWithValues: fields.map { ($0.name, $0.values.map(\.resolved)) })
    }

    public func field(named name: String) -> AnkiNoteDraftField? {
        fields.first { $0.name == name }
    }

    public mutating func update(field name: String, _ change: (inout AnkiNoteDraftField) -> Void) {
        guard let index = fields.firstIndex(where: { $0.name == name }) else { return }
        change(&fields[index])
    }

    public mutating func update(field name: String, value id: UUID, _ change: (inout AnkiNoteDraftValue) -> Void) {
        update(field: name) { field in
            guard let index = field.values.firstIndex(where: { $0.id == id }) else { return }
            change(&field.values[index])
        }
    }

    /// Pitch accent values are derived from the reading, so they no longer apply once the reading is edited.
    public mutating func clearPitchAccentValues() {
        for fieldIndex in fields.indices {
            for valueIndex in fields[fieldIndex].values.indices
                where fields[fieldIndex].values[valueIndex].template.isPitchAccent
            {
                fields[fieldIndex].values[valueIndex].resolved = .empty
            }
        }
    }
}

public extension TemplateResolvedValue {
    /// The text as a provider sends it, with the media it references inlined. Empty for media-only values.
    var previewHTML: String {
        guard text?.isEmpty == false else { return "" }
        return AnkiFieldValueFormatter.buildFieldValues(from: ["": [self]])[""] ?? ""
    }
}

public extension AnkiNoteDraftField {
    /// The field's text values as a provider sends them; see `TemplateResolvedValue.previewHTML`.
    var previewHTML: String {
        values.map(\.resolved.previewHTML).joined()
    }
}

public extension TemplateValue {
    var isPitchAccent: Bool {
        switch self {
        case .singlePitchAccent, .singlePitchAccentDictionary, .pitchAccentList,
             .pitchAccentDisambiguation, .pitchAccentCategories:
            true
        default:
            false
        }
    }
}
