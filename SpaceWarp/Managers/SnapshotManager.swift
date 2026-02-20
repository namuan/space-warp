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
        self.configManager = configManager
        self.repository = SnapshotRepository()
        
        Task {
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
        let snapshot = Snapshot(
            name: name,
            description: description,
            windows: windows,
            displays: displays
        )
        
        try await repository.save(snapshot)
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
        isLoading = true
        defer { isLoading = false }
        
        do {
            snapshots = try await repository.loadAll()
            lastError = nil
        } catch {
            lastError = error
            snapshots = []
        }
    }
    
    /// Deletes a snapshot
    /// - Parameter snapshot: Snapshot to delete
    func deleteSnapshot(_ snapshot: Snapshot) async throws {
        try await repository.delete(snapshot)
        snapshots.removeAll { $0.id == snapshot.id }
        notifySnapshotsChanged()
    }
    
    /// Removes an app from a snapshot
    /// - Parameters:
    ///   - snapshot: The snapshot to modify
    ///   - appName: App name to remove
    func removeAppFromSnapshot(_ snapshot: Snapshot, appName: String) async throws {
        let updated = snapshot.removing(appName: appName)
        try await repository.update(updated)
        
        if let index = snapshots.firstIndex(where: { $0.id == snapshot.id }) {
            snapshots[index] = updated
        }
        notifySnapshotsChanged()
    }
    
    /// Renames a snapshot
    /// - Parameters:
    ///   - snapshot: The snapshot to rename
    ///   - newName: New name
    func renameSnapshot(_ snapshot: Snapshot, newName: String) async throws {
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
        
        try await repository.update(updated)
        
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
