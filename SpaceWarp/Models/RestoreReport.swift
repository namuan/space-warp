//
//  RestoreReport.swift
//  SpaceWarp
//
//  Data model representing the result of a snapshot restore operation.
//

import AppKit
import Foundation

// MARK: - RestoreReport

/// Represents the result of a snapshot restoration operation.
struct RestoreReport: Codable, Identifiable {
    // MARK: - Properties
    
    let id: UUID
    let snapshotName: String
    let snapshotId: UUID
    let startedAt: Date
    let finishedAt: Date
    let total: Int
    let restoredCount: Int
    let failedCount: Int
    let items: [RestoreItem]
    
    // MARK: - Computed Properties
    
    var success: Bool { failedCount == 0 }
    var duration: TimeInterval { finishedAt.timeIntervalSince(startedAt) }
    var successRate: Double {
        guard total > 0 else { return 0 }
        return Double(restoredCount) / Double(total) * 100
    }
    
    /// Formatted duration string
    var formattedDuration: String {
        let seconds = Int(duration)
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return "\(minutes)m \(remainingSeconds)s"
    }
    
    /// Summary string
    var summary: String {
        "\(restoredCount)/\(total) windows restored in \(formattedDuration)"
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        snapshotName: String,
        snapshotId: UUID,
        startedAt: Date,
        finishedAt: Date,
        total: Int,
        restoredCount: Int,
        failedCount: Int,
        items: [RestoreItem]
    ) {
        self.id = id
        self.snapshotName = snapshotName
        self.snapshotId = snapshotId
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.total = total
        self.restoredCount = restoredCount
        self.failedCount = failedCount
        self.items = items
    }
}

// MARK: - RestoreItem

/// Represents the result of restoring a single window.
struct RestoreItem: Codable, Identifiable, Hashable {
    // MARK: - Properties
    
    let id: UUID
    let appName: String
    let windowTitle: String
    let restored: Bool
    let launched: Bool
    let launchCommand: String?
    let reason: String?
    
    // MARK: - Computed Properties
    
    var status: RestoreItemStatus {
        if restored {
            return .restored
        } else if let reason {
            return .failed(reason)
        } else if launched {
            return .launched
        }
        return .pending
    }
    
    var statusIcon: String {
        switch status {
        case .restored:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .launched:
            return "arrowtriangle.right.circle.fill"
        case .pending:
            return "circle"
        }
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        appName: String,
        windowTitle: String,
        restored: Bool,
        launched: Bool,
        launchCommand: String? = nil,
        reason: String? = nil
    ) {
        self.id = id
        self.appName = appName
        self.windowTitle = windowTitle
        self.restored = restored
        self.launched = launched
        self.launchCommand = launchCommand
        self.reason = reason
    }
}

// MARK: - RestoreItemStatus

enum RestoreItemStatus: Equatable {
    case restored
    case launched
    case pending
    case failed(String)
}

// MARK: - Extensions

extension RestoreReport {
    /// Creates an empty report for a failed operation
    static func failed(snapshotName: String, snapshotId: UUID, reason: String) -> RestoreReport {
        RestoreReport(
            snapshotName: snapshotName,
            snapshotId: snapshotId,
            startedAt: Date(),
            finishedAt: Date(),
            total: 0,
            restoredCount: 0,
            failedCount: 1,
            items: [
                RestoreItem(
                    appName: "System",
                    windowTitle: "",
                    restored: false,
                    launched: false,
                    reason: reason
                )
            ]
        )
    }
    
    /// Groups items by application
    var itemsByApp: [String: [RestoreItem]] {
        Dictionary(grouping: items, by: \.appName)
    }
}
