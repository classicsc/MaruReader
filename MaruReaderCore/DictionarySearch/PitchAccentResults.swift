import Foundation

public struct PitchAccentResults: Identifiable, Sendable {
    public let dictionaryTitle: String
    public let dictionaryID: UUID
    public let priority: Int
    public let pitches: [PitchAccent]

    public var id: String { "\(dictionaryID)" }
}
