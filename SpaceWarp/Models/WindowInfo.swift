//
//  WindowInfo.swift
//  SpaceWarp
//
//  Data model representing a captured window state.
//

import AppKit
import Foundation

// MARK: - WindowInfo

/// Represents a captured window with all its properties for restoration.
struct WindowInfo: Codable, Identifiable, Hashable {
    // MARK: - Properties
    
    let id: UUID
    
    /// Name of the application owning the window
    let appName: String
    
    /// Window title/caption
    let windowTitle: String
    
    /// X position in global coordinates
    let x: Int
    
    /// Y position in global coordinates
    let y: Int
    
    /// Window width in pixels
    let width: Int
    
    /// Window height in pixels
    let height: Int
    
    /// Whether the window is minimized
    let isMinimized: Bool
    
    /// Whether the application is hidden
    let isHidden: Bool
    
    /// Display ID where the window resides
    let displayId: Int
    
    /// Process ID of the owning application
    let pid: Int32
    
    /// Bundle identifier of the application
    let bundleId: String?
    
    /// Space ID (macOS space/desktop)
    let spaceId: Int?
    
    /// CGWindowID for window reference
    let windowId: Int?
    
    // MARK: - Computed Properties
    
    /// Window frame as CGRect
    var rect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
    
    /// Display name, preferring bundle ID
    var displayName: String {
        bundleId ?? appName
    }
    
    /// Whether the window appears to be valid for restoration
    var isValid: Bool {
        width > 0 && height > 0 && !appName.isEmpty
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        appName: String,
        windowTitle: String,
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        isMinimized: Bool,
        isHidden: Bool,
        displayId: Int,
        pid: Int32,
        bundleId: String?,
        spaceId: Int?,
        windowId: Int?
    ) {
        self.id = id
        self.appName = appName
        self.windowTitle = windowTitle
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.isMinimized = isMinimized
        self.isHidden = isHidden
        self.displayId = displayId
        self.pid = pid
        self.bundleId = bundleId
        self.spaceId = spaceId
        self.windowId = windowId
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id
        case appName
        case windowTitle
        case x
        case y
        case width
        case height
        case isMinimized
        case isHidden
        case displayId
        case pid
        case bundleId
        case spaceId
        case windowId
    }
}

// MARK: - Extensions

extension WindowInfo {
    /// Creates a window info with updated position
    func withPosition(x: Int, y: Int) -> WindowInfo {
        WindowInfo(
            id: id,
            appName: appName,
            windowTitle: windowTitle,
            x: x,
            y: y,
            width: width,
            height: height,
            isMinimized: isMinimized,
            isHidden: isHidden,
            displayId: displayId,
            pid: pid,
            bundleId: bundleId,
            spaceId: spaceId,
            windowId: windowId
        )
    }
    
    /// Creates a window info with updated size
    func withSize(width: Int, height: Int) -> WindowInfo {
        WindowInfo(
            id: id,
            appName: appName,
            windowTitle: windowTitle,
            x: x,
            y: y,
            width: width,
            height: height,
            isMinimized: isMinimized,
            isHidden: isHidden,
            displayId: displayId,
            pid: pid,
            bundleId: bundleId,
            spaceId: spaceId,
            windowId: windowId
        )
    }
}
