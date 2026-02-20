//
//  DisplayInfo.swift
//  SpaceWarp
//
//  Data model representing a connected display.
//

import AppKit
import Foundation

// MARK: - DisplayInfo

/// Represents a connected display with its properties.
struct DisplayInfo: Codable, Identifiable, Hashable {
    // MARK: - Properties
    
    let id: UUID
    
    /// CGDirectDisplayID
    let displayId: Int
    
    /// Display name/model
    let name: String
    
    /// Width in pixels
    let width: Int
    
    /// Height in pixels
    let height: Int
    
    /// X position in global coordinates
    let x: Int
    
    /// Y position in global coordinates
    let y: Int
    
    /// Whether this is the main display
    let isMain: Bool
    
    // MARK: - Computed Properties
    
    /// Display frame as CGRect
    var rect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
    
    /// Center point of the display
    var center: CGPoint {
        CGPoint(x: x + width / 2, y: y + height / 2)
    }
    
    /// Human-readable description
    var description: String {
        "\(name) (\(width)×\(height))\(isMain ? " [Main]" : "")"
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        displayId: Int,
        name: String,
        width: Int,
        height: Int,
        x: Int,
        y: Int,
        isMain: Bool
    ) {
        self.id = id
        self.displayId = displayId
        self.name = name
        self.width = width
        self.height = height
        self.x = x
        self.y = y
        self.isMain = isMain
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(displayId)
    }
    
    static func == (lhs: DisplayInfo, rhs: DisplayInfo) -> Bool {
        lhs.displayId == rhs.displayId
    }
}

// MARK: - Extensions

extension DisplayInfo {
    /// Checks if a point is within this display
    func contains(point: CGPoint) -> Bool {
        rect.contains(point)
    }
    
    /// Checks if a rectangle intersects with this display
    func intersects(rect: CGRect) -> Bool {
        self.rect.intersects(rect)
    }
    
    /// Calculates intersection area with a rectangle
    func intersectionArea(with otherRect: CGRect) -> CGFloat {
        let intersection = rect.intersection(otherRect)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }
}
