import Foundation
import OSLog

public protocol AppLogging: Sendable {
    func debug(_ message: String, category: String)
    func info(_ message: String, category: String)
    func error(_ message: String, category: String)
}

public struct ConsoleAppLogger: AppLogging, Sendable {
    private let logger = Logger(subsystem: "com.jacobrozell.mechbuddy", category: "App")

    public init() {}

    public func debug(_ message: String, category: String) {
        logger.debug("[\(category)] \(message)")
    }

    public func info(_ message: String, category: String) {
        logger.info("[\(category)] \(message)")
    }

    public func error(_ message: String, category: String) {
        logger.error("[\(category)] \(message)")
    }
}
