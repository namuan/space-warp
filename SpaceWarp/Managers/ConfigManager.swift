//
//  ConfigManager.swift
//  SpaceWarp
//
//  Application settings management.
//

import Combine
import Defaults
import Foundation

// MARK: - ConfigManager

/// Manages application settings and configuration.
@MainActor
final class ConfigManager: ObservableObject {
    // MARK: - Published Properties
    
    @Published var settings: AppSettings
    
    // MARK: - Computed Properties
    
    var configDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("SpaceWarp")
        
        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        
        return appDir
    }
    
    var databasePath: URL {
        configDirectory.appendingPathComponent("SpaceWarp.db")
    }
    
    // MARK: - Initialization
    
    init() {
        self.settings = Defaults[.settings]
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    /// Saves current settings
    func save() {
        Defaults[.settings] = settings
    }
    
    /// Resets to default settings
    func resetToDefaults() {
        settings = AppSettings()
        save()
    }
    
    /// Updates a specific setting
    func update(_ keyPath: WritableKeyPath<AppSettings, Bool>, value: Bool) {
        settings[keyPath: keyPath] = value
        save()
    }
    
    /// Updates a specific setting
    func update(_ keyPath: WritableKeyPath<AppSettings, Int>, value: Int) {
        settings[keyPath: keyPath] = value
        save()
    }
    
    /// Updates a specific setting
    func update(_ keyPath: WritableKeyPath<AppSettings, String>, value: String) {
        settings[keyPath: keyPath] = value
        save()
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe defaults changes
        Task {
            for await _ in Defaults.updates(.settings) {
                settings = Defaults[.settings]
            }
        }
    }
}

// MARK: - LaunchAtLoginManager

extension ConfigManager {
    /// Manages "Launch at Login" functionality
    var launchAtLoginEnabled: Bool {
        get {
            // Use SMAppService for macOS 13+
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            }
            return false
        }
        set {
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    // Handle error silently
                }
            }
        }
    }
}

// MARK: - SMAppService (macOS 13+)

@available(macOS 13.0, *)
enum SMAppService {
    static var mainApp: MainAppService = MainAppService()
    
    enum Status {
        case enabled
        case notRegistered
    }
    
    final class MainAppService {
        var status: Status {
            // Check launch agent status
            let plistName = Bundle.main.bundleIdentifier ?? "com.spacewarp"
            let launchAgentsPath = "~/Library/LaunchAgents/\(plistName).plist"
            let path = (launchAgentsPath as NSString).expandingTildeInPath
            return FileManager.default.fileExists(atPath: path) ? .enabled : .notRegistered
        }
        
        func register() throws {
            // Create launch agent plist
            let plistName = Bundle.main.bundleIdentifier ?? "com.spacewarp"
            let launchAgentsPath = (("~/Library/LaunchAgents" as NSString).expandingTildeInPath)
            let plistPath = (launchAgentsPath as NSString).appendingPathComponent("\(plistName).plist")
            
            // Ensure directory exists
            try FileManager.default.createDirectory(atPath: launchAgentsPath, withIntermediateDirectories: true)
            
            let executablePath = Bundle.main.executablePath ?? ""
            let plist: [String: Any] = [
                "Label": plistName,
                "ProgramArguments": [executablePath],
                "RunAtLoad": false,
                "KeepAlive": false
            ]
            
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: URL(fileURLWithPath: plistPath))
        }
        
        func unregister() throws {
            let plistName = Bundle.main.bundleIdentifier ?? "com.spacewarp"
            let plistPath = ("~/Library/LaunchAgents/\(plistName).plist" as NSString).expandingTildeInPath
            try FileManager.default.removeItem(atPath: plistPath)
        }
    }
}
