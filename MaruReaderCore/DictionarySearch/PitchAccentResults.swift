import Foundation

public struct PitchAccentResults: Identifiable, Sendable {
    public let dictionaryTitle: String
    public let dictionaryID: UUID
    public let priority: Int
    public let pitches: [PitchAccent]

    public var id: String { "\(dictionaryID)" }

    public init(dictionaryTitle: String, dictionaryID: UUID, priority: Int, pitches: [PitchAccent]) {
        self.dictionaryTitle = dictionaryTitle
        self.dictionaryID = dictionaryID
        self.priority = priority
        self.pitches = pitches
    }
}
