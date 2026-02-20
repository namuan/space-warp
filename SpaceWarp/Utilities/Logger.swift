//
//  Logger.swift
//  SpaceWarp
//
//  Centralized logging utility.
//

import Foundation
import Logging

// MARK: - Logger

/// Global logger instance for SpaceWarp.
let logger = Logger(label: "com.spacewarp")

// MARK: - LogCategory

/// Logging categories for SpaceWarp.
enum LogCategory: String {
    case general = "General"
    case windowManager = "WindowManager"
    case snapshotManager = "SnapshotManager"
    case permission = "Permission"
    case hotkey = "Hotkey"
    case display = "Display"
    case database = "Database"
    case ui = "UI"
}

// MARK: - Logger Extension

extension Logger {
    /// Creates a logger with a specific category.
    static func category(_ category: LogCategory) -> Logger {
        Logger(label: "com.spacewarp.\(category.rawValue.lowercased())")
    }
    
    /// Logs a debug message with context.
    func debugMessage(_ message: String, file: String = #file, function: String = #function, line: UInt = #line) {
        let fileName = (file as NSString).lastPathComponent
        self.debug("[\(fileName):\(line)] \(function) - \(message)")
    }
    
    /// Logs an error with context.
    func logError(_ error: Error, file: String = #file, function: String = #function, line: UInt = #line) {
        let fileName = (file as NSString).lastPathComponent
        self.error("[\(fileName):\(line)] \(function) - \(error.localizedDescription)")
    }
}
