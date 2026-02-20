//
//  Snapshot.swift
//  SpaceWarp
//
//  Data model representing a saved window layout snapshot.
//

import AppKit
import Foundation

// MARK: - Snapshot

/// Represents a saved window layout snapshot.
struct Snapshot: Codable, Identifiable, Hashable {
    // MARK: - Properties
    
    let id: UUID
    let name: String
    let description: String
    let createdAt: Date
    let windows: [WindowInfo]
    let displays: [DisplayInfo]
    let metadata: [String: String]
    
    // MARK: - Computed Properties
    
    var windowCount: Int { windows.count }
    var displayCount: Int { displays.count }
    
    /// Formatted creation date
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    /// Unique application names in this snapshot
    var uniqueAppNames: [String] {
        Array(Set(windows.map(\.appName))).sorted()
    }
    
    /// Bundle IDs for apps in this snapshot
    var bundleIds: [String] {
        windows.compactMap(\.bundleId)
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        createdAt: Date = Date(),
        windows: [WindowInfo],
        displays: [DisplayInfo],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.createdAt = createdAt
        self.windows = windows
        self.displays = displays
        self.metadata = metadata
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Snapshot, rhs: Snapshot) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Extensions

extension Snapshot {
    /// Creates a snapshot with windows filtered by app name
    func filtered(byAppName appName: String) -> Snapshot {
        Snapshot(
            id: id,
            name: name,
            description: description,
            createdAt: createdAt,
            windows: windows.filter { $0.appName == appName },
            displays: displays,
            metadata: metadata
        )
    }
    
    /// Creates a snapshot with an app removed
    func removing(appName: String) -> Snapshot {
        Snapshot(
            id: id,
            name: name,
            description: description,
            createdAt: createdAt,
            windows: windows.filter { $0.appName != appName },
            displays: displays,
            metadata: metadata
        )
    }
    
    /// Checks if this snapshot has matching display configuration
    func hasMatchingDisplays(with currentDisplays: [DisplayInfo]) -> Bool {
        Set(displays.map(\.displayId)) == Set(currentDisplays.map(\.displayId))
    }
    
    /// Finds missing displays compared to current configuration
    func missingDisplays(comparedTo currentDisplays: [DisplayInfo]) -> [DisplayInfo] {
        let currentIds = Set(currentDisplays.map(\.displayId))
        return displays.filter { !currentIds.contains($0.displayId) }
    }
}
