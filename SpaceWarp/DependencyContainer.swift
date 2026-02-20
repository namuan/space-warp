//
//  DependencyContainer.swift
//  SpaceWarp
//
//  Centralized dependency injection container.
//

import Foundation

// MARK: - DependencyContainer

/// Centralized dependency injection container for the application.
/// Provides singleton access to all view models and managers.
@MainActor
final class DependencyContainer: ObservableObject {
    // MARK: - Singleton
    
    static let shared = DependencyContainer()
    
    // MARK: - Managers
    
    let windowManager: WindowManager
    let snapshotManager: SnapshotManager
    let configManager: ConfigManager
    let permissionManager: PermissionManager
    
    // MARK: - View Models
    
    @Published var windowViewModel: WindowViewModel
    @Published var snapshotViewModel: SnapshotViewModel
    @Published var settingsViewModel: SettingsViewModel
    
    // MARK: - Initialization
    
    private init() {
        // Initialize managers
        self.windowManager = WindowManager()
        self.configManager = ConfigManager()
        
        // Initialize snapshot manager with dependencies
        self.snapshotManager = SnapshotManager(configManager: configManager)
        
        // Initialize permission manager
        self.permissionManager = PermissionManager()
        
        // Initialize view models
        self.windowViewModel = WindowViewModel(windowManager: windowManager)
        self.snapshotViewModel = SnapshotViewModel(
            snapshotManager: snapshotManager,
            windowManager: windowManager
        )
        self.settingsViewModel = SettingsViewModel(configManager: configManager)
    }
}
