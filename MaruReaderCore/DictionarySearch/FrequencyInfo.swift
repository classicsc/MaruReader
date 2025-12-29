import Foundation

public struct FrequencyInfo: Sendable {
    public let dictionaryID: UUID
    public let dictionaryTitle: String
    public let value: Double
    public let mode: String?
    public let priority: Int
}
