//
//  PermissionManager.swift
//  SpaceWarp
//
//  macOS permission checking and requesting.
//

import AppKit
import Combine
import CoreGraphics
import Foundation

// MARK: - PermissionManager

/// Manages macOS permission checks and requests.
@MainActor
final class PermissionManager: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var screenRecordingGranted = false
    @Published private(set) var automationGranted = false
    @Published var shouldShowPermissionSheet = false
    
    // MARK: - Computed Properties
    
    var allPermissionsGranted: Bool {
        accessibilityGranted && screenRecordingGranted && automationGranted
    }
    
    var missingPermissions: [PermissionType] {
        var missing: [PermissionType] = []
        if !accessibilityGranted { missing.append(.accessibility) }
        if !screenRecordingGranted { missing.append(.screenRecording) }
        if !automationGranted { missing.append(.automation) }
        return missing
    }
    
    var missingPermissionNames: [String] {
        missingPermissions.map(\.displayName)
    }
    
    // MARK: - Initialization
    
    init() {
        Task {
            await checkPermissions()
        }
    }
    
    // MARK: - Public Methods
    
    /// Checks all required permissions
    func checkPermissions() async {
        accessibilityGranted = checkAccessibility()
        screenRecordingGranted = checkScreenRecording()
        automationGranted = checkAutomation()
        
        if !allPermissionsGranted {
            shouldShowPermissionSheet = true
        }
    }
    
    /// Requests accessibility permission
    func requestAccessibilityPermission() async -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let result = AXIsProcessTrustedWithOptions(options as CFDictionary)
        accessibilityGranted = result
        return result
    }
    
    /// Requests screen recording permission
    /// - Note: This triggers the system prompt
    func requestScreenRecordingPermission() async -> Bool {
        // On macOS 10.15+, screen recording requires user approval
        // We can only check if we have it, the system handles the prompt
        
        // Try to capture a screenshot to trigger the permission request
        let mainDisplay = CGMainDisplayID()
        guard let image = CGDisplayCreateImage(mainDisplay) else {
            return false
        }
        
        // If we got an image, we have permission
        screenRecordingGranted = image.width > 0
        return screenRecordingGranted
    }
    
    /// Requests automation permission
    func requestAutomationPermission() async -> Bool {
        // Try to use AppleScript to control System Events
        // This will trigger a permission prompt if needed
        let script = """
        tell application "System Events"
            return name of first process
        end tell
        """
        
        if let result = try? NSAppleScript(source: script)?.executeAndReturnError(nil) {
            automationGranted = result.stringValue != nil
            return automationGranted
        }
        
        return false
    }
    
    /// Opens System Settings to the appropriate section
    func openSystemPreferences(section: String = "Privacy") {
        // macOS Ventura+ uses System Settings
        let url: URL?
        switch section {
        case "Privacy":
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        default:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security")
        }
        
        if let url {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Opens System Settings to Accessibility
    func openAccessibilitySettings() {
        openSystemPreferences(section: "Privacy")
    }
    
    // MARK: - Private Methods
    
    private func checkAccessibility() -> Bool {
        AXIsProcessTrusted()
    }
    
    private func checkScreenRecording() -> Bool {
        // Check if we can capture screen content
        let mainDisplay = CGMainDisplayID()
        guard let image = CGDisplayCreateImage(mainDisplay) else { return false }
        
        return image.width > 0
    }
    
    private func checkAutomation() -> Bool {
        // Check if we can control System Events
        let script = """
        tell application "System Events"
            return true
        end tell
        """
        
        if let result = try? NSAppleScript(source: script)?.executeAndReturnError(nil) {
            return result.booleanValue
        }
        
        return false
    }
}

// MARK: - PermissionType

enum PermissionType: String, CaseIterable {
    case accessibility
    case screenRecording
    case automation
    
    var displayName: String {
        switch self {
        case .accessibility: return "Accessibility"
        case .screenRecording: return "Screen Recording"
        case .automation: return "Automation"
        }
    }
    
    var description: String {
        switch self {
        case .accessibility:
            return "Required for window management and positioning"
        case .screenRecording:
            return "Required for display configuration detection"
        case .automation:
            return "Required for launching applications"
        }
    }
    
    var systemImage: String {
        switch self {
        case .accessibility: return "figure.walk.circle"
        case .screenRecording: return "rectangle.on.rectangle"
        case .automation: return "gearshape.2"
        }
    }
}
