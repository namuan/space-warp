//
//  SnapshotManager.swift
//  SpaceWarp
//
//  Manages snapshot persistence and retrieval.
//

import Combine
import Foundation

// MARK: - SnapshotManager

/// Manages snapshot CRUD operations and persistence.
@MainActor
final class SnapshotManager: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var snapshots: [Snapshot] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: Error?
    
    // MARK: - Private Properties
    
    private let repository: SnapshotRepository
    private let configManager: ConfigManager
    private var autoSaveTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(configManager: ConfigManager) {
        LoggerService.shared.info("SnapshotManager initializing", category: "SnapshotManager")
        self.configManager = configManager
        self.repository = SnapshotRepository()
        
        Task {
            LoggerService.shared.debug("Starting initial snapshot load", category: "SnapshotManager")
            await loadSnapshots()
            await startAutoSaveIfNeeded()
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Saves a new snapshot
    /// - Parameters:
    ///   - name: Snapshot name
    ///   - description: Optional description
    ///   - windows: Windows to include
    ///   - displays: Current display configuration
    /// - Returns: The created snapshot
    func saveSnapshot(
        name: String,
        description: String = "",
        windows: [WindowInfo],
        displays: [DisplayInfo]
    ) async throws -> Snapshot {
        LoggerService.shared.info("Saving snapshot: \(name)", category: "SnapshotManager")
        LoggerService.shared.debug("Snapshot details - windows: \(windows.count), displays: \(displays.count)", category: "SnapshotManager")
        
        let snapshot = Snapshot(
            name: name,
            description: description,
            windows: windows,
            displays: displays
        )
        
        LoggerService.shared.debug("Saving snapshot to repository: \(snapshot.id)", category: "SnapshotManager")
        try await repository.save(snapshot)
        LoggerService.shared.info("Snapshot saved to database: \(snapshot.id)", category: "SnapshotManager")
        
        snapshots.append(snapshot)
        notifySnapshotsChanged()
        
        return snapshot
    }
    
    /// Gets a snapshot by name
    /// - Parameter name: Snapshot name
    /// - Returns: The snapshot if found
    func getSnapshot(name: String) async -> Snapshot? {
        snapshots.first { $0.name == name }
    }
    
    /// Gets a snapshot by ID
    /// - Parameter id: Snapshot ID
    /// - Returns: The snapshot if found
    func getSnapshot(id: UUID) async -> Snapshot? {
        snapshots.first { $0.id == id }
    }
    
    /// Loads all snapshots from storage
    func loadSnapshots() async {
        LoggerService.shared.info("Loading snapshots from database", category: "SnapshotManager")
        isLoading = true
        defer { 
            isLoading = false
            LoggerService.shared.debug("loadSnapshots completed", category: "SnapshotManager")
        }
        
        do {
            snapshots = try await repository.loadAll()
            LoggerService.shared.info("Loaded \(snapshots.count) snapshots from database", category: "SnapshotManager")
            LoggerService.shared.debug("Snapshot IDs: \(snapshots.map { $0.id.uuidString }.joined(separator: ", "))", category: "SnapshotManager")
            lastError = nil
        } catch {
            LoggerService.shared.error("Failed to load snapshots: \(error.localizedDescription)", category: "SnapshotManager")
            lastError = error
            snapshots = []
        }
    }
    
    /// Deletes a snapshot
    /// - Parameter snapshot: Snapshot to delete
    func deleteSnapshot(_ snapshot: Snapshot) async throws {
        LoggerService.shared.info("Deleting snapshot: \(snapshot.name) (\(snapshot.id))", category: "SnapshotManager")
        
        LoggerService.shared.debug("Deleting from repository", category: "SnapshotManager")
        try await repository.delete(snapshot)
        LoggerService.shared.info("Snapshot deleted from database: \(snapshot.id)", category: "SnapshotManager")
        
        snapshots.removeAll { $0.id == snapshot.id }
        notifySnapshotsChanged()
    }
    
    /// Removes an app from a snapshot
    /// - Parameters:
    ///   - snapshot: The snapshot to modify
    ///   - appName: App name to remove
    func removeAppFromSnapshot(_ snapshot: Snapshot, appName: String) async throws {
        LoggerService.shared.info("Removing app '\(appName)' from snapshot: \(snapshot.name)", category: "SnapshotManager")
        
        let updated = snapshot.removing(appName: appName)
        LoggerService.shared.debug("Updating snapshot in repository", category: "SnapshotManager")
        try await repository.update(updated)
        LoggerService.shared.info("Snapshot updated in database after removing app: \(appName)", category: "SnapshotManager")
        
        if let index = snapshots.firstIndex(where: { $0.id == snapshot.id }) {
            snapshots[index] = updated
            LoggerService.shared.debug("Updated snapshot in memory at index: \(index)", category: "SnapshotManager")
        }
        notifySnapshotsChanged()
    }
    
    /// Renames a snapshot
    /// - Parameters:
    ///   - snapshot: The snapshot to rename
    ///   - newName: New name
    func renameSnapshot(_ snapshot: Snapshot, newName: String) async throws {
        LoggerService.shared.info("Renaming snapshot: \(snapshot.name) -> \(newName)", category: "SnapshotManager")
        
        var updated = snapshot
        updated = Snapshot(
            id: snapshot.id,
            name: newName,
            description: snapshot.description,
            createdAt: snapshot.createdAt,
            windows: snapshot.windows,
            displays: snapshot.displays,
            metadata: snapshot.metadata
        )
        
        LoggerService.shared.debug("Updating snapshot in repository", category: "SnapshotManager")
        try await repository.update(updated)
        LoggerService.shared.info("Snapshot renamed in database: \(snapshot.id)", category: "SnapshotManager")
        
        if let index = snapshots.firstIndex(where: { $0.id == snapshot.id }) {
            snapshots[index] = updated
        }
        notifySnapshotsChanged()
    }
    
    // MARK: - Auto-save
    
    /// Saves current window state as auto-save
    func autoSaveSnapshot() async throws {
        // This would capture current windows and save with timestamp
        let name = "Auto-save \(Date().formatted(date: .abbreviated, time: .shortened))"
        
        // Would need WindowManager to capture current windows
        // For now, just the interface
        _ = name
    }
    
    private func startAutoSaveIfNeeded() async {
        let interval = configManager.settings.snapshots.autoSaveInterval
        guard interval > 0 else { return }
        
        autoSaveTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
                
                if !Task.isCancelled {
                    try? await autoSaveSnapshot()
                }
            }
        }
    }
    
    // MARK: - Utility
    
    /// Gets the most recent snapshot
    var mostRecentSnapshot: Snapshot? {
        snapshots.max(by: { $0.createdAt < $1.createdAt })
    }
    
    private func notifySnapshotsChanged() {
        NotificationCenter.default.post(name: .snapshotsDidChange, object: nil)
    }
}
