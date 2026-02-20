//
//  ContentView.swift
//  SpaceWarp
//
//  Main application content view.
//

import AppKit
import Foundation
import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    // MARK: - Environment Objects
    
    @EnvironmentObject var windowViewModel: WindowViewModel
    @EnvironmentObject var snapshotViewModel: SnapshotViewModel
    @EnvironmentObject var permissionManager: PermissionManager
    
    // MARK: - State
    
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            if permissionManager.allPermissionsGranted {
                mainContent
            } else {
                PermissionView()
            }
        }
        .onAppear {
            LoggerService.shared.info("ContentView appeared", category: "ContentView")
            LoggerService.shared.debug("Permission state - allGranted: \(permissionManager.allPermissionsGranted)", category: "ContentView")
            windowViewModel.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            LoggerService.shared.debug("App became active, refreshing windows", category: "ContentView")
            windowViewModel.refresh()
        }
        .sheet(isPresented: $snapshotViewModel.showSaveSheet) {
            SaveSnapshotSheet()
        }
        .sheet(isPresented: $snapshotViewModel.showRestoreReport) {
            if let report = snapshotViewModel.lastRestoreReport {
                RestoreReportView(report: report)
            }
        }
        .alert("Error", isPresented: .init(
            get: { snapshotViewModel.errorMessage != nil },
            set: { if !$0 { snapshotViewModel.clearError() } }
        )) {
            Button("OK") {
                snapshotViewModel.clearError()
            }
        } message: {
            if let error = snapshotViewModel.errorMessage {
                Text(error)
            }
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            WindowListView()
                .navigationTitle("Current Windows")
                .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
                .toolbar {
                    ToolbarItemGroup {
                        if windowViewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        
                        Button {
                            windowViewModel.refresh()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .help("Refresh window list")
                        
                        Button {
                            snapshotViewModel.showSaveSheet = true
                        } label: {
                            Label("Save Snapshot", systemImage: "camera")
                        }
                        .help("Save current layout as snapshot")
                    }
                }
        } content: {
            SnapshotListView()
                .navigationTitle("Saved Snapshots")
                .navigationSplitViewColumnWidth(min: 300, ideal: 400, max: 500)
        } detail: {
            if let snapshot = snapshotViewModel.selectedSnapshot {
                SnapshotDetailView(snapshot: snapshot) {
                    snapshotViewModel.selectedSnapshot = nil
                }
                .environmentObject(snapshotViewModel)
            } else {
                Text("Select a snapshot to view details")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - SaveSnapshotSheet

struct SaveSnapshotSheet: View {
    @EnvironmentObject var snapshotViewModel: SnapshotViewModel
    @EnvironmentObject var windowViewModel: WindowViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var description = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Save Snapshot")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Show window count
            HStack {
                Image(systemName: "rectangle.on.rectangle")
                Text("\(windowViewModel.windowCount) windows across \(windowViewModel.displayCount) display(s)")
                    .foregroundColor(.secondary)
            }
            
            Form {
                TextField("Name", text: $name)
                TextField("Description (optional)", text: $description)
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save") {
                    Task {
                        await snapshotViewModel.saveSnapshot(name: name, description: description)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || windowViewModel.windowCount == 0)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

// MARK: - RestoreReportView

struct RestoreReportView: View {
    let report: RestoreReport
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: report.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundColor(report.success ? .green : .orange)
                
                VStack(alignment: .leading) {
                    Text(report.success ? "Restore Complete" : "Restore Finished with Errors")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(report.summary)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(report.items) { item in
                        HStack {
                            Image(systemName: item.statusIcon)
                                .foregroundColor(item.restored ? .green : .red)
                            
                            VStack(alignment: .leading) {
                                Text(item.appName)
                                    .fontWeight(.medium)
                                if !item.windowTitle.isEmpty {
                                    Text(item.windowTitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if let reason = item.reason {
                                    Text(reason)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            
                            Spacer()
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
            
            HStack {
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 500, height: 450)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(WindowViewModel(windowManager: WindowManager()))
        .environmentObject(SnapshotViewModel(
            snapshotManager: SnapshotManager(configManager: ConfigManager()),
            windowManager: WindowManager()
        ))
        .environmentObject(PermissionManager())
}
