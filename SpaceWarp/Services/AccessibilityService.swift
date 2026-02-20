//
//  AccessibilityService.swift
//  SpaceWarp
//
//  Wrapper for macOS Accessibility APIs.
//

import AppKit
import Foundation

// MARK: - AccessibilityService

/// Provides access to macOS Accessibility APIs for window manipulation.
final class AccessibilityService {
    // MARK: - Public Methods
    
    /// Checks if the process is trusted for accessibility
    /// - Returns: Whether accessibility is granted
    func isProcessTrusted() -> Bool {
        AXIsProcessTrusted()
    }
    
    /// Requests trusted access (shows system prompt)
    /// - Returns: Whether access was granted
    func requestTrustedAccess() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    /// Moves and resizes a window
    /// - Parameters:
    ///   - pid: Process ID of the owning application
    ///   - rect: Target rectangle for the window
    ///   - title: Optional window title for matching
    /// - Returns: Success boolean
    func moveWindow(pid: Int32, rect: CGRect, title: String? = nil) async throws -> Bool {
        let appElement = AXUIElementCreateApplication(pid)
        
        // Get all windows for the app
        var windowsValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
        
        guard result == .success, let windows = windowsValue as? [AXUIElement] else {
            throw AccessibilityError.noWindowsFound
        }
        
        // Find the target window
        let targetWindow: AXUIElement?
        if let title, !title.isEmpty {
            targetWindow = windows.first { window in
                var titleValue: CFTypeRef?
                AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
                return (titleValue as? String) == title
            }
        } else {
            targetWindow = windows.first
        }
        
        guard let window = targetWindow else {
            throw AccessibilityError.windowNotFound
        }
        
        // Set position
        var origin = rect.origin
        guard let positionValue = AXValueCreate(.cgPoint, &origin) else {
            throw AccessibilityError.positionSetFailed
        }
        let positionResult = AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            positionValue
        )
        
        // Set size
        var size = rect.size
        guard let sizeValue = AXValueCreate(.cgSize, &size) else {
            throw AccessibilityError.sizeSetFailed
        }
        let sizeResult = AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            sizeValue
        )
        
        return positionResult == .success && sizeResult == .success
    }
    
    /// Gets all windows for an application
    /// - Parameter pid: Process ID
    /// - Returns: Array of window elements
    func getWindows(forPID pid: Int32) -> [AXUIElement] {
        let appElement = AXUIElementCreateApplication(pid)
        
        var windowsValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
        
        guard result == .success, let windows = windowsValue as? [AXUIElement] else {
            return []
        }
        
        return windows
    }
    
    /// Gets the position and size of a window
    /// - Parameter element: Window AXUIElement
    /// - Returns: Window frame
    func getWindowFrame(_ element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        
        let positionResult = AXUIElementCopyAttributeValue(
            element,
            kAXPositionAttribute as CFString,
            &positionValue
        )
        let sizeResult = AXUIElementCopyAttributeValue(
            element,
            kAXSizeAttribute as CFString,
            &sizeValue
        )
        
        guard positionResult == .success, sizeResult == .success else {
            return nil
        }
        
        var position = CGPoint.zero
        var size = CGSize.zero
        
        guard let posVal = positionValue,
              let szVal = sizeValue,
              AXValueGetValue(posVal as! AXValue, .cgPoint, &position),
              AXValueGetValue(szVal as! AXValue, .cgSize, &size) else {
            return nil
        }
        
        return CGRect(origin: position, size: size)
    }
    
    /// Minimizes a window
    /// - Parameter element: Window AXUIElement
    /// - Returns: Success boolean
    func minimizeWindow(_ element: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanTrue) == .success
    }
    
    /// Unminimizes a window
    /// - Parameter element: Window AXUIElement
    /// - Returns: Success boolean
    func unminimizeWindow(_ element: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanFalse) == .success
    }
    
    /// Focuses a window
    /// - Parameter element: Window AXUIElement
    /// - Returns: Success boolean
    func focusWindow(_ element: AXUIElement) -> Bool {
        AXUIElementPerformAction(element, kAXRaiseAction as CFString) == .success
    }
}

// MARK: - AccessibilityError

enum AccessibilityError: Error, LocalizedError {
    case noWindowsFound
    case windowNotFound
    case positionSetFailed
    case sizeSetFailed
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .noWindowsFound: return "No windows found for application"
        case .windowNotFound: return "Target window not found"
        case .positionSetFailed: return "Failed to set window position"
        case .sizeSetFailed: return "Failed to set window size"
        case .permissionDenied: return "Accessibility permission not granted"
        }
    }
}

// MARK: - AXError Extension

extension AXError {
    var isSuccess: Bool {
        self == .success
    }
    
    var success: Bool {
        self == .success
    }
}
