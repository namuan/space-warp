//
//  SettingsViewModel.swift
//  SpaceWarp
//
//  View model for settings management.
//

import AppKit
import Combine
import Foundation

// MARK: - SettingsViewModel

/// Manages application settings state.
@MainActor
final class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var settings: AppSettings
    
    // MARK: - Private Properties
    
    private let configManager: ConfigManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(configManager: ConfigManager) {
        self.configManager = configManager
        self.settings = configManager.settings
        
        // Bind to config manager changes
        configManager.$settings
            .receive(on: DispatchQueue.main)
            .assign(to: &$settings)
    }
    
    // MARK: - General Settings
    
    /// Updates start minimized setting
    func updateStartMinimized(_ value: Bool) {
        settings.startMinimized = value
        configManager.save()
    }
    
    /// Updates auto start (launch at login) setting
    func updateAutoStart(_ value: Bool) {
        settings.autoStart = value
        configManager.save()
        configManager.launchAtLoginEnabled = value
    }
    
    /// Updates show in menu bar setting
    func updateShowInMenuBar(_ value: Bool) {
        settings.showInMenuBar = value
        configManager.save()
    }
    
    // MARK: - Hotkey Settings
    
    /// Updates save snapshot hotkey
    func updateSaveSnapshotHotkey(_ value: String) {
        settings.hotkeys.saveSnapshot = value
        configManager.save()
    }
    
    /// Updates restore last snapshot hotkey
    func updateRestoreLastSnapshotHotkey(_ value: String) {
        settings.hotkeys.restoreLastSnapshot = value
        configManager.save()
    }
    
    /// Updates toggle window manager hotkey
    func updateToggleWindowManagerHotkey(_ value: String) {
        settings.hotkeys.toggleWindowManager = value
        configManager.save()
    }
    
    // MARK: - Display Settings
    
    /// Updates auto adjust missing displays setting
    func updateAutoAdjustMissingDisplays(_ value: Bool) {
        settings.display.autoAdjustMissingDisplays = value
        configManager.save()
    }
    
    /// Updates prompt for missing displays setting
    func updatePromptForMissingDisplays(_ value: Bool) {
        settings.display.promptForMissingDisplays = value
        configManager.save()
    }
    
    // MARK: - Snapshot Settings
    
    /// Updates auto save interval
    func updateAutoSaveInterval(_ value: Int) {
        settings.snapshots.autoSaveInterval = value
        configManager.save()
    }
    
    /// Updates max snapshots
    func updateMaxSnapshots(_ value: Int) {
        settings.snapshots.maxSnapshots = value
        configManager.save()
    }
    
    /// Updates confirm before restore setting
    func updateConfirmBeforeRestore(_ value: Bool) {
        settings.snapshots.confirmBeforeRestore = value
        configManager.save()
    }
    
    /// Updates show restore report setting
    func updateShowRestoreReport(_ value: Bool) {
        settings.snapshots.showRestoreReport = value
        configManager.save()
    }
    
    // MARK: - Advanced Settings
    
    /// Updates debug mode
    func updateDebugMode(_ value: Bool) {
        settings.debugMode = value
        configManager.save()
    }
    
    /// Updates log level
    func updateLogLevel(_ value: LogLevel) {
        settings.logLevel = value
        configManager.save()
    }
    
    // MARK: - Actions
    
    /// Resets all settings to defaults
    func resetToDefaults() {
        configManager.resetToDefaults()
    }
}
