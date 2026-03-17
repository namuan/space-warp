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
        LoggerService.shared.info("SnapshotViewModel initializing", category: "SnapshotViewModel")
        self.snapshotManager = snapshotManager
        self.windowManager = windowManager
        
        // Bind to manager's snapshots
        Task {
            LoggerService.shared.debug("Starting to observe snapshotManager.$snapshots", category: "SnapshotViewModel")
            for await value in snapshotManager.$snapshots.values {
                snapshots = value
                LoggerService.shared.info("Snapshots loaded: \(value.count) snapshots", category: "SnapshotViewModel")
                LoggerService.shared.debug("Snapshot names: \(value.map { $0.name }.joined(separator: ", "))", category: "SnapshotViewModel")
            }
        }
    }
    
    // MARK: - Save Operations
    
    /// Saves a new snapshot
    /// - Parameters:
    ///   - name: Snapshot name
    ///   - description: Optional description
    func saveSnapshot(name: String, description: String = "") async {
        LoggerService.shared.info("Starting saveSnapshot: \(name)", category: "SnapshotViewModel")
        LoggerService.shared.debug("Snapshot description: \(description.isEmpty ? "none" : description)", category: "SnapshotViewModel")
        isSaving = true
        defer { 
            isSaving = false
            LoggerService.shared.debug("saveSnapshot completed", category: "SnapshotViewModel")
        }
        
        do {
            let windows = await windowManager.getWindows()
            let displays = await windowManager.getDisplays()
            LoggerService.shared.debug("Captured \(windows.count) windows and \(displays.count) displays", category: "SnapshotViewModel")
            
            let snapshot = try await snapshotManager.saveSnapshot(
                name: name,
                description: description,
                windows: windows,
                displays: displays
            )
            
            LoggerService.shared.info("Snapshot saved successfully: \(snapshot.id)", category: "SnapshotViewModel")
            selectedSnapshot = snapshot
            showSaveSheet = false
        } catch {
            LoggerService.shared.error("Failed to save snapshot: \(error.localizedDescription)", category: "SnapshotViewModel")
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
        LoggerService.shared.info("Starting restoreSnapshot: \(snapshot.name)", category: "SnapshotViewModel")
        LoggerService.shared.debug("Snapshot has \(snapshot.windowCount) windows", category: "SnapshotViewModel")
        isRestoring = true
        defer { 
            isRestoring = false
            LoggerService.shared.debug("restoreSnapshot completed", category: "SnapshotViewModel")
        }
        
        let report = await windowManager.restoreLayout(snapshot)
        LoggerService.shared.info("Restore completed - success: \(report.success), items: \(report.items.count)", category: "SnapshotViewModel")
        lastRestoreReport = report
        showRestoreReport = true
    }
    
    /// Restores the last/most recent snapshot
    func restoreLastSnapshot() async {
        LoggerService.shared.info("Attempting to restore last snapshot", category: "SnapshotViewModel")
        guard let snapshot = snapshotManager.mostRecentSnapshot else {
            LoggerService.shared.error("No snapshots available to restore", category: "SnapshotViewModel")
            errorMessage = "No snapshots available to restore"
            return
        }
        
        LoggerService.shared.debug("Most recent snapshot: \(snapshot.name)", category: "SnapshotViewModel")
        await restoreSnapshot(snapshot)
    }
    
    // MARK: - Delete Operations
    
    /// Deletes a snapshot
    /// - Parameter snapshot: Snapshot to delete
    func deleteSnapshot(_ snapshot: Snapshot) async {
        LoggerService.shared.info("Starting deleteSnapshot: \(snapshot.name)", category: "SnapshotViewModel")
        do {
            try await snapshotManager.deleteSnapshot(snapshot)
            LoggerService.shared.info("Snapshot deleted successfully: \(snapshot.name)", category: "SnapshotViewModel")
            
            if selectedSnapshot?.id == snapshot.id {
                selectedSnapshot = nil
                LoggerService.shared.debug("Cleared selectedSnapshot (was the deleted snapshot)", category: "SnapshotViewModel")
            }
        } catch {
            LoggerService.shared.error("Failed to delete snapshot: \(error.localizedDescription)", category: "SnapshotViewModel")
            errorMessage = "Failed to delete snapshot: \(error.localizedDescription)"
        }
    }
    
    /// Removes an app from a snapshot
    /// - Parameters:
    ///   - appName: App name to remove
    ///   - snapshot: Snapshot to modify
    func removeApp(appName: String, from snapshot: Snapshot) async {
        LoggerService.shared.info("Starting removeApp: \(appName) from snapshot: \(snapshot.name)", category: "SnapshotViewModel")
        errorMessage = nil
        do {
            try await snapshotManager.removeAppFromSnapshot(snapshot, appName: appName)
            LoggerService.shared.info("Successfully removed app: \(appName) from snapshot: \(snapshot.name)", category: "SnapshotViewModel")
        } catch {
            LoggerService.shared.error("Failed to remove app \(appName): \(error.localizedDescription)", category: "SnapshotViewModel")
            errorMessage = "Failed to remove app: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Selection
    
    /// Selects a snapshot
    /// - Parameter snapshot: Snapshot to select
    func select(_ snapshot: Snapshot?) {
        if let snapshot = snapshot {
            LoggerService.shared.info("Selecting snapshot: \(snapshot.name)", category: "SnapshotViewModel")
        } else {
            LoggerService.shared.info("Clearing snapshot selection", category: "SnapshotViewModel")
        }
        selectedSnapshot = snapshot
    }
    
    /// Clears the selection
    func clearSelection() {
        LoggerService.shared.info("Clearing snapshot selection", category: "SnapshotViewModel")
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
