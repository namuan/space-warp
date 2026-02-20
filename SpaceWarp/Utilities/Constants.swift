//
//  Constants.swift
//  SpaceWarp
//
//  Application-wide constants and configuration.
//

import AppKit
import Foundation

// MARK: - Constants

/// Application-wide constants.
enum Constants {
    // MARK: - App Info
    
    static let appIdentifier = "com.spacewarp"
    static let appName = "SpaceWarp"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    
    // MARK: - Timing
    
    /// Default timeout for app launch waiting (seconds)
    static let appLaunchTimeout: TimeInterval = 30
    
    /// Default timeout for window appearance (seconds)
    static let windowAppearTimeout: TimeInterval = 10
    
    /// Default backoff interval for polling (seconds)
    static let defaultBackoffInterval: TimeInterval = 0.15
    
    /// Maximum backoff interval (seconds)
    static let maxBackoffInterval: TimeInterval = 2.0
    
    /// Auto-save check interval (seconds)
    static let autoSaveCheckInterval: TimeInterval = 60
    
    // MARK: - Window Filtering
    
    /// Window owners to exclude from capture
    static let excludedWindowOwners = [
        "Window Server",
        "Dock",
        "TaskSwitcher",
        "loginwindow",
        "WindowManager"
    ]
    
    /// Minimum window dimensions to consider valid
    static let minValidWindowWidth: CGFloat = 1
    static let minValidWindowHeight: CGFloat = 1
    
    // MARK: - Database
    
    /// Database file name
    static let databaseFileName = "SpaceWarp.db"
    
    /// Maximum snapshots to keep (default)
    static let defaultMaxSnapshots = 50
    
    // MARK: - UI
    
    /// Minimum window size for the app
    static let appMinimumWindowWidth: CGFloat = 900
    static let appMinimumWindowHeight: CGFloat = 600
    
    /// Settings window size
    static let settingsWindowWidth: CGFloat = 500
    static let settingsWindowHeight: CGFloat = 400
    
    // MARK: - Hotkeys
    
    /// Default hotkey configurations
    static let defaultSaveSnapshotHotkey = "⌃⇧S"
    static let defaultRestoreLastHotkey = "⌃⇧R"
    static let defaultToggleManagerHotkey = "⌃⇧M"
}

// MARK: - Notification Names

extension Notification.Name {
    static let windowListDidChange = Notification.Name("com.spacewarp.windowListDidChange")
    static let displayConfigurationDidChange = Notification.Name("com.spacewarp.displayConfigurationDidChange")
    static let restoreDidComplete = Notification.Name("com.spacewarp.restoreDidComplete")
}

// MARK: - UserDefaults Keys

enum UserDefaultsKey {
    static let settings = "com.spacewarp.settings"
    static let lastSnapshotId = "com.spacewarp.lastSnapshotId"
    static let hasCompletedOnboarding = "com.spacewarp.hasCompletedOnboarding"
    static let lastRestoreTime = "com.spacewarp.lastRestoreTime"
}
