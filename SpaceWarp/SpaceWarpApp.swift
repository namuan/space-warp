//
//  SpaceWarpApp.swift
//  SpaceWarp
//
//  Multi-display window and app layout manager for macOS.
//

import AppKit
import SwiftUI

@main
struct SpaceWarpApp: App {
    // MARK: - Properties
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var dependencyContainer = DependencyContainer.shared
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dependencyContainer.windowViewModel)
                .environmentObject(dependencyContainer.snapshotViewModel)
                .environmentObject(dependencyContainer.permissionManager)
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
            
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    appDelegate.openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(dependencyContainer.settingsViewModel)
        }
    }
}
