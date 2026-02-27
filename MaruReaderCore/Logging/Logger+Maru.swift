import os

public extension Logger {
    /// Creates a Logger with the MaruReader subsystem.
    static func maru(category: String) -> Logger {
        Logger(subsystem: "net.undefinedstar.MaruReader", category: category)
    }
}
