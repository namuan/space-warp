//
//  AppSettings.swift
//  SpaceWarp
//
//  Application settings and configuration models.
//

import AppKit
import Defaults
import Foundation

// MARK: - AppSettings

/// Main application settings model.
struct AppSettings: Codable, Defaults.Serializable {
    // MARK: - General
    
    var startMinimized: Bool = false
    var autoStart: Bool = false
    var showInMenuBar: Bool = true
    
    // MARK: - Hotkeys
    
    var hotkeys: HotkeyConfiguration = .init()
    
    // MARK: - Display
    
    var display: DisplayConfiguration = .init()
    
    // MARK: - Snapshots
    
    var snapshots: SnapshotConfiguration = .init()
    
    // MARK: - Advanced
    
    var debugMode: Bool = false
    var logLevel: LogLevel = .info
}

// MARK: - HotkeyConfiguration

/// Keyboard shortcut configuration.
struct HotkeyConfiguration: Codable, Defaults.Serializable {
    var saveSnapshot: String = "⌃⇧S"
    var restoreLastSnapshot: String = "⌃⇧R"
    var toggleWindowManager: String = "⌃⇧M"
    
    /// Parses a key combo string into modifiers and key
    func parse(keyCombo: String) -> (modifiers: NSEvent.ModifierFlags, key: String)? {
        var modifiers: NSEvent.ModifierFlags = []
        var key = keyCombo
        
        if key.contains("⌃") { modifiers.insert(.control); key = key.replacingOccurrences(of: "⌃", with: "") }
        if key.contains("⌥") { modifiers.insert(.option); key = key.replacingOccurrences(of: "⌥", with: "") }
        if key.contains("⇧") { modifiers.insert(.shift); key = key.replacingOccurrences(of: "⇧", with: "") }
        if key.contains("⌘") { modifiers.insert(.command); key = key.replacingOccurrences(of: "⌘", with: "") }
        
        key = key.trimmingCharacters(in: .whitespaces)
        return (modifiers, key)
    }
}

// MARK: - DisplayConfiguration

/// Display-related configuration.
struct DisplayConfiguration: Codable, Defaults.Serializable {
    var autoAdjustMissingDisplays: Bool = true
    var promptForMissingDisplays: Bool = true
    var rememberDisplayAssignments: Bool = true
}

// MARK: - SnapshotConfiguration

/// Snapshot-related configuration.
struct SnapshotConfiguration: Codable, Defaults.Serializable {
    var autoSaveInterval: Int = 300  // seconds, 0 = disabled
    var maxSnapshots: Int = 50
    var confirmBeforeRestore: Bool = true
    var showRestoreReport: Bool = true
}

// MARK: - LogLevel

/// Logging verbosity level.
enum LogLevel: String, Codable, Defaults.Serializable, CaseIterable {
    case debug
    case info
    case warning
    case error
    
    var displayName: String {
        switch self {
        case .debug: return "Debug"
        case .info: return "Info"
        case .warning: return "Warning"
        case .error: return "Error"
        }
    }
}

// MARK: - Defaults Keys

extension Defaults.Keys {
    static let settings = Key<AppSettings>("com.spacewarp.settings", default: .init())
    static let lastSnapshotId = Key<String?>("com.spacewarp.lastSnapshotId")
    static let hasCompletedOnboarding = Key<Bool>("com.spacewarp.hasCompletedOnboarding", default: false)
}
