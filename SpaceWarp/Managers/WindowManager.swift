//
//  WindowManager.swift
//  SpaceWarp
//
//  Window capture and restoration manager.
//

import AppKit
import Combine
import CoreGraphics
import Foundation

// MARK: - WindowManager

/// Manages window capture and restoration using macOS APIs.
@MainActor
final class WindowManager: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var isPermissionGranted = false
    @Published private(set) var isCapturing = false
    @Published private(set) var lastError: Error?
    @Published private(set) var statusMessage: String = "Ready"
    
    // MARK: - Private Properties
    
    private let workspace = NSWorkspace.shared
    private let accessibilityService = AccessibilityService()
    private let displayService = DisplayService()
    private let skylightService = SkyLightService()
    
    // MARK: - Initialization
    
    init() {
        checkPermissions()
    }
    
    // MARK: - Public Methods
    
    /// Checks if required permissions are granted
    func checkPermissions() {
        let hasAccessibility = accessibilityService.isProcessTrusted()
        
        // Check screen recording by trying to capture main display
        let mainDisplay = CGMainDisplayID()
        let hasScreenRecording: Bool
        if let image = CGDisplayCreateImage(mainDisplay) {
            hasScreenRecording = image.width > 0
        } else {
            hasScreenRecording = false
        }
        
        isPermissionGranted = hasAccessibility
        
        if !hasAccessibility {
            statusMessage = "Accessibility permission required"
        } else if !hasScreenRecording {
            statusMessage = "Screen Recording permission may be needed for some windows"
        } else {
            statusMessage = "Permissions granted"
        }
    }
    
    /// Gets all connected displays
    /// - Returns: Array of DisplayInfo
    func getDisplays() async -> [DisplayInfo] {
        displayService.getDisplays()
    }
    
    /// Gets all visible windows
    /// - Parameter appName: Optional filter by application name
    /// - Returns: Array of WindowInfo
    func getWindows(filterByApp appName: String? = nil) async -> [WindowInfo] {
        isCapturing = true
        statusMessage = "Capturing windows..."
        defer { 
            isCapturing = false
            statusMessage = "Ready"
        }
        
        do {
            let windows = try await captureWindows(filterByApp: appName)
            lastError = nil
            statusMessage = "Found \(windows.count) windows"
            return windows
        } catch {
            lastError = error
            statusMessage = "Error: \(error.localizedDescription)"
            return []
        }
    }
    
    /// Gets windows across all spaces (requires SkyLight)
    /// - Parameter appName: Optional filter by application name
    /// - Returns: Array of WindowInfo
    func getWindowsAllSpaces(filterByApp appName: String? = nil) async -> [WindowInfo] {
        return await getWindows(filterByApp: appName)
    }
    
    /// Restores a single window to its saved position
    /// - Parameter window: Window to restore
    /// - Returns: Success boolean
    func restoreWindow(_ window: WindowInfo) async -> Bool {
        guard isPermissionGranted else { return false }
        
        do {
            let success = try await performWindowRestore(window)
            return success
        } catch {
            lastError = error
            return false
        }
    }
    
    /// Restores a complete snapshot layout
    /// - Parameter snapshot: Snapshot to restore
    /// - Returns: RestoreReport with results
    func restoreLayout(_ snapshot: Snapshot) async -> RestoreReport {
        let startedAt = Date()
        var items: [RestoreItem] = []
        
        // Hide non-profile apps first
        await hideNonProfileApps(snapshot: snapshot)
        
        // Get current windows for matching
        let currentWindows = await getWindows()
        
        // Restore each window
        for window in snapshot.windows {
            let item = await restoreWindowInSnapshot(
                window,
                currentWindows: currentWindows
            )
            items.append(item)
        }
        
        let finishedAt = Date()
        let restoredCount = items.filter(\.restored).count
        
        return RestoreReport(
            snapshotName: snapshot.name,
            snapshotId: snapshot.id,
            startedAt: startedAt,
            finishedAt: finishedAt,
            total: items.count,
            restoredCount: restoredCount,
            failedCount: items.count - restoredCount,
            items: items
        )
    }
    
    /// Launches an application by bundle ID or name
    /// - Parameter bundleId: Bundle identifier or app name
    /// - Returns: Success boolean
    func launchApp(bundleId: String) async -> Bool {
        // Try bundle ID first
        if let url = workspace.urlForApplication(withBundleIdentifier: bundleId) {
            let config = NSWorkspace.OpenConfiguration()
            return (try? await workspace.openApplication(at: url, configuration: config)) != nil
        }
        
        // Fallback to name
        return workspace.launchApplication(bundleId)
    }
    
    /// Hides an application
    /// - Parameter app: The application to hide
    func hideApp(_ app: NSRunningApplication) {
        app.hide()
    }
    
    /// Unhides an application
    /// - Parameter app: The application to unhide
    func unhideApp(_ app: NSRunningApplication) {
        app.unhide()
    }
    
    // MARK: - Private Methods
    
    private func captureWindows(filterByApp appName: String?) async throws -> [WindowInfo] {
        let displayInfo = displayService.getDisplays()
        
        // Use CGWindowListCopyWindowInfo to get window list
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            throw WindowError.captureFailed("Could not get window list")
        }
        
        let runningApps = workspace.runningApplications
        var bundleByPID: [Int32: String] = [:]
        for app in runningApps {
            if let bundleId = app.bundleIdentifier {
                bundleByPID[app.processIdentifier] = bundleId
            }
        }
        
        var capturedWindows: [WindowInfo] = []
        
        for windowDict in windowList {
            if let window = parseWindowDict(
                windowDict,
                filterByApp: appName,
                displayInfo: displayInfo,
                bundleByPID: bundleByPID,
                runningApps: runningApps
            ) {
                capturedWindows.append(window)
            }
        }
        
        return capturedWindows
    }
    
    private func parseWindowDict(
        _ dict: [String: Any],
        filterByApp appName: String?,
        displayInfo: [DisplayInfo],
        bundleByPID: [Int32: String],
        runningApps: [NSRunningApplication]
    ) -> WindowInfo? {
        // Get window owner name
        guard let ownerName = dict[kCGWindowOwnerName as String] as? String,
              !ownerName.isEmpty else {
            return nil
        }
        
        // Filter out system windows
        let excludedOwners = ["Window Server", "Dock", "TaskSwitcher", "loginwindow"]
        guard !excludedOwners.contains(ownerName) else {
            return nil
        }
        
        // Get PID
        guard let pid = dict[kCGWindowOwnerPID as String] as? Int32 else {
            return nil
        }
        
        // Get bounds
        guard let boundsDict = dict[kCGWindowBounds as String] as? [String: CGFloat] else {
            return nil
        }
        
        let width = Int(boundsDict["Width"] ?? 0)
        let height = Int(boundsDict["Height"] ?? 0)
        
        // Skip tiny windows (but allow small utility windows)
        guard width >= 50, height >= 50 else {
            return nil
        }
        
        // Filter by app name if provided
        if let filter = appName, ownerName != filter {
            return nil
        }
        
        let x = Int(boundsDict["X"] ?? 0)
        let y = Int(boundsDict["Y"] ?? 0)
        let windowTitle = dict[kCGWindowName as String] as? String ?? ""
        let windowId = dict[kCGWindowNumber as String] as? Int
        
        // Get display for this window
        let displayId = displayService.getDisplayForWindow(x: x, y: y, displays: displayInfo)
        
        // Get app info
        let app = runningApps.first { $0.processIdentifier == pid }
        
        return WindowInfo(
            appName: ownerName,
            windowTitle: windowTitle,
            x: x,
            y: y,
            width: width,
            height: height,
            isMinimized: app?.isHidden ?? false,
            isHidden: app?.isHidden ?? false,
            displayId: displayId,
            pid: pid,
            bundleId: bundleByPID[pid],
            spaceId: nil,
            windowId: windowId
        )
    }
    
    private func performWindowRestore(_ window: WindowInfo) async throws -> Bool {
        // Activate the app first
        if let app = workspace.runningApplications.first(where: { $0.processIdentifier == window.pid }) {
            app.activate(options: .activateIgnoringOtherApps)
        }
        
        // Use Accessibility API to move/resize
        return try await accessibilityService.moveWindow(
            pid: window.pid,
            rect: window.rect,
            title: window.windowTitle.isEmpty ? nil : window.windowTitle
        )
    }
    
    private func restoreWindowInSnapshot(
        _ window: WindowInfo,
        currentWindows: [WindowInfo]
    ) async -> RestoreItem {
        // Try to find matching window
        if let existing = findMatchingWindow(window: window, in: currentWindows) {
            let restored = await restoreWindow(existing)
            return RestoreItem(
                appName: window.appName,
                windowTitle: window.windowTitle,
                restored: restored,
                launched: false,
                reason: restored ? nil : "restore_failed"
            )
        }
        
        // Need to launch the app
        guard let bundleId = window.bundleId else {
            return RestoreItem(
                appName: window.appName,
                windowTitle: window.windowTitle,
                restored: false,
                launched: false,
                reason: "no_bundle_id"
            )
        }
        
        let launched = await launchApp(bundleId: bundleId)
        if !launched {
            return RestoreItem(
                appName: window.appName,
                windowTitle: window.windowTitle,
                restored: false,
                launched: false,
                reason: "launch_failed"
            )
        }
        
        // Wait for window to appear
        if let newWindow = await waitForWindow(appName: window.appName, timeout: 30) {
            let restored = await restoreWindow(newWindow)
            return RestoreItem(
                appName: window.appName,
                windowTitle: window.windowTitle,
                restored: restored,
                launched: true,
                reason: restored ? nil : "restore_failed"
            )
        }
        
        return RestoreItem(
            appName: window.appName,
            windowTitle: window.windowTitle,
            restored: false,
            launched: true,
            reason: "window_timeout"
        )
    }
    
    private func findMatchingWindow(window: WindowInfo, in windows: [WindowInfo]) -> WindowInfo? {
        // Exact title match first
        if let exact = windows.first(where: { $0.windowTitle == window.windowTitle && $0.appName == window.appName }) {
            return exact
        }
        
        // Any window from same app
        return windows.first { $0.appName == window.appName }
    }
    
    private func waitForWindow(appName: String, timeout: TimeInterval) async -> WindowInfo? {
        let startTime = Date()
        var backoff: TimeInterval = 0.15
        
        while Date().timeIntervalSince(startTime) < timeout {
            try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
            
            let windows = await getWindows(filterByApp: appName)
            if let window = windows.first {
                return window
            }
            
            backoff = min(backoff * 1.1, 2.0)
        }
        
        return nil
    }
    
    private func hideNonProfileApps(snapshot: Snapshot) async {
        let keepNames = Set(snapshot.windows.map(\.appName))
        let keepBundleIds = Set(snapshot.windows.compactMap(\.bundleId))
        
        for app in workspace.runningApplications {
            guard app.activationPolicy == .regular else { continue }
            
            if let bundleId = app.bundleIdentifier, keepBundleIds.contains(bundleId) { continue }
            if let name = app.localizedName, keepNames.contains(name) { continue }
            
            app.hide()
        }
    }
}

// MARK: - WindowError

enum WindowError: Error, LocalizedError {
    case captureFailed(String)
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .captureFailed(let message): return message
        case .permissionDenied: return "Permission denied"
        }
    }
}
