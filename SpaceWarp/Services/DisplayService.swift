//
//  DisplayService.swift
//  SpaceWarp
//
//  Display enumeration and management.
//

import AppKit
import CoreGraphics
import Foundation

// MARK: - DisplayService

/// Provides access to display information and management.
final class DisplayService {
    // MARK: - Public Methods
    
    /// Gets all currently connected displays
    /// - Returns: Array of DisplayInfo
    func getDisplays() -> [DisplayInfo] {
        var displayIds: [CGDirectDisplayID] = Array(repeating: 0, count: 32)
        var count: UInt32 = 0
        
        let error = CGGetOnlineDisplayList(32, &displayIds, &count)
        guard error == .success else {
            return fallbackDisplays()
        }
        
        return displayIds.prefix(Int(count)).compactMap { id -> DisplayInfo? in
            let bounds = CGDisplayBounds(id)
            let name = getDisplayName(id)
            let isMain = CGDisplayIsMain(id) != 0
            
            return DisplayInfo(
                displayId: Int(id),
                name: name,
                width: Int(bounds.width),
                height: Int(bounds.height),
                x: Int(bounds.origin.x),
                y: Int(bounds.origin.y),
                isMain: isMain
            )
        }
    }
    
    /// Gets the display containing a given point
    /// - Parameter point: Global coordinates
    /// - Returns: DisplayInfo if found
    func getDisplay(containing point: CGPoint) -> DisplayInfo? {
        let displays = getDisplays()
        return displays.first { $0.rect.contains(point) }
    }
    
    /// Gets the display for a window at given coordinates
    /// - Parameters:
    ///   - x: Window X coordinate
    ///   - y: Window Y coordinate
    ///   - displays: Available displays
    /// - Returns: Display ID
    func getDisplayForWindow(x: Int, y: Int, displays: [DisplayInfo]) -> Int {
        let windowRect = CGRect(x: x, y: y, width: 1, height: 1)
        
        // Find display with largest intersection
        var bestDisplay: DisplayInfo?
        var bestArea: CGFloat = -1
        
        for display in displays {
            let intersection = display.rect.intersection(windowRect)
            if intersection.isNull { continue }
            
            let area = intersection.width * intersection.height
            if area > bestArea {
                bestArea = area
                bestDisplay = display
            }
        }
        
        return bestDisplay?.displayId ?? Int(CGMainDisplayID())
    }
    
    /// Gets the main display
    /// - Returns: Main display info
    func getMainDisplay() -> DisplayInfo? {
        getDisplays().first { $0.isMain }
    }
    
    /// Gets display by ID
    /// - Parameter id: Display ID
    /// - Returns: DisplayInfo if found
    func getDisplay(byID id: Int) -> DisplayInfo? {
        getDisplays().first { $0.displayId == id }
    }
    
    /// Checks if display configuration has changed
    /// - Parameter previousDisplays: Previous display configuration
    /// - Returns: Whether configuration changed
    func hasDisplayConfigurationChanged(from previousDisplays: [DisplayInfo]) -> Bool {
        let currentDisplays = getDisplays()
        
        let previousIds = Set(previousDisplays.map(\.displayId))
        let currentIds = Set(currentDisplays.map(\.displayId))
        
        return previousIds != currentIds
    }
    
    // MARK: - Private Methods
    
    private func getDisplayName(_ displayId: CGDirectDisplayID) -> String {
        // Try to get display name
        if let name = CGDisplayModelName(displayId) {
            return name
        }
        
        // Fallback to generic name
        let vendor = CGDisplayVendorNumber(displayId)
        let model = CGDisplayModelNumber(displayId)
        
        if CGDisplayIsBuiltin(displayId) != 0 {
            return "Built-in Display"
        }
        
        return "Display \(vendor)-\(model)"
    }
    
    private func fallbackDisplays() -> [DisplayInfo] {
        // Return a single default display
        let mainDisplayId = CGMainDisplayID()
        let bounds = CGDisplayBounds(mainDisplayId)
        
        return [
            DisplayInfo(
                displayId: Int(mainDisplayId),
                name: "Main Display",
                width: Int(bounds.width),
                height: Int(bounds.height),
                x: Int(bounds.origin.x),
                y: Int(bounds.origin.y),
                isMain: true
            )
        ]
    }
}

// MARK: - CGDisplayModelName

/// Gets the display model name
func CGDisplayModelName(_ displayID: CGDirectDisplayID) -> String? {
    // This is a simplified version
    // In production, you'd use CoreDisplay or IOKit for proper names
    
    if CGDisplayIsBuiltin(displayID) != 0 {
        return "Built-in Retina Display"
    }
    
    // Get vendor and model info
    let vendor = CGDisplayVendorNumber(displayID)
    let model = CGDisplayModelNumber(displayID)
    
    // Map known vendor/model combinations
    if vendor == 0x610 {
        return "Apple Display"
    }
    
    return "Display (\(vendor), \(model))"
}
