//
//  SnapshotViewModel.swift
//  SpaceWarp
//
//  View model for snapshot management.
//

import AppKit
import Combine
import Foundation

// MARK: - SnapshotViewModel

/// Manages the state of snapshots view.
@MainActor
final class SnapshotViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var snapshots: [Snapshot] = []
    @Published var selectedSnapshot: Snapshot?  // Public setter for binding
    @Published private(set) var isSaving = false
    @Published private(set) var isRestoring = false
    @Published private(set) var lastRestoreReport: RestoreReport?
    @Published var showSaveSheet = false
    @Published var showRestoreReport = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let snapshotManager: SnapshotManager
    private let windowManager: WindowManager
    
    // MARK: - Computed Properties
    
    var snapshotCount: Int { snapshots.count }
    
    // MARK: - Initialization
    
    init(snapshotManager: SnapshotManager, windowManager: WindowManager) {
        self.snapshotManager = snapshotManager
        self.windowManager = windowManager
        
        // Bind to manager's snapshots
        Task {
            for await value in snapshotManager.$snapshots.values {
                snapshots = value
            }
        }
    }
    
    // MARK: - Save Operations
    
    /// Saves a new snapshot
    /// - Parameters:
    ///   - name: Snapshot name
    ///   - description: Optional description
    func saveSnapshot(name: String, description: String = "") async {
        isSaving = true
        defer { isSaving = false }
        
        do {
            let windows = await windowManager.getWindows()
            let displays = await windowManager.getDisplays()
            
            let snapshot = try await snapshotManager.saveSnapshot(
                name: name,
                description: description,
                windows: windows,
                displays: displays
            )
            
            selectedSnapshot = snapshot
            showSaveSheet = false
        } catch {
            errorMessage = "Failed to save snapshot: \(error.localizedDescription)"
        }
    }
    
    /// Saves a quick snapshot with auto-generated name
    func saveQuickSnapshot() async {
        let name = "Snapshot \(Date().formatted(date: .abbreviated, time: .shortened))"
        await saveSnapshot(name: name)
    }
    
    // MARK: - Restore Operations
    
    /// Restores a snapshot
    /// - Parameter snapshot: Snapshot to restore
    func restoreSnapshot(_ snapshot: Snapshot) async {
        isRestoring = true
        defer { isRestoring = false }
        
        let report = await windowManager.restoreLayout(snapshot)
        lastRestoreReport = report
        showRestoreReport = true
    }
    
    /// Restores the last/most recent snapshot
    func restoreLastSnapshot() async {
        guard let snapshot = snapshotManager.mostRecentSnapshot else {
            errorMessage = "No snapshots available to restore"
            return
        }
        
        await restoreSnapshot(snapshot)
    }
    
    // MARK: - Delete Operations
    
    /// Deletes a snapshot
    /// - Parameter snapshot: Snapshot to delete
    func deleteSnapshot(_ snapshot: Snapshot) async {
        do {
            try await snapshotManager.deleteSnapshot(snapshot)
            
            if selectedSnapshot?.id == snapshot.id {
                selectedSnapshot = nil
            }
        } catch {
            errorMessage = "Failed to delete snapshot: \(error.localizedDescription)"
        }
    }
    
    /// Removes an app from a snapshot
    /// - Parameters:
    ///   - appName: App name to remove
    ///   - snapshot: Snapshot to modify
    func removeApp(appName: String, from snapshot: Snapshot) async {
        do {
            try await snapshotManager.removeAppFromSnapshot(snapshot, appName: appName)
        } catch {
            errorMessage = "Failed to remove app: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Selection
    
    /// Selects a snapshot
    /// - Parameter snapshot: Snapshot to select
    func select(_ snapshot: Snapshot?) {
        selectedSnapshot = snapshot
    }
    
    /// Clears the selection
    func clearSelection() {
        selectedSnapshot = nil
    }
    
    // MARK: - Utility
    
    /// Clears any error message
    func clearError() {
        errorMessage = nil
    }
    
    /// Dismisses the restore report
    func dismissRestoreReport() {
        showRestoreReport = false
    }
}
