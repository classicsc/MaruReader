import Foundation

public struct FrequencyInfo: Sendable {
    public let dictionaryID: UUID
    public let dictionaryTitle: String
    public let value: Double
    public let displayValue: String?
    public let mode: String?
    public let priority: Int

    /// The string to display for this frequency.
    /// Uses `displayValue` if available, otherwise formats `value` as an integer.
    public var displayString: String {
        displayValue ?? String(Int(round(value)))
    }
}
