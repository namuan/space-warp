//
//  SnapshotListView.swift
//  SpaceWarp
//
//  Displays and manages saved snapshots.
//

import AppKit
import Foundation
import SwiftUI

// MARK: - SnapshotListView

struct SnapshotListView: View {
    @EnvironmentObject var snapshotViewModel: SnapshotViewModel
    
    var body: some View {
        List(selection: $snapshotViewModel.selectedSnapshot) {
            ForEach(snapshotViewModel.snapshots) { snapshot in
                SnapshotCard(snapshot: snapshot)
                    .tag(snapshot)
                    .contextMenu {
                        snapshotContextMenu(for: snapshot)
                    }
            }
        }
        .listStyle(.inset)
        .onChange(of: snapshotViewModel.selectedSnapshot) { newValue in
            handleSelectionChange(newValue)
        }
        .overlay {
            emptyOverlay
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    if let snapshot = snapshotViewModel.selectedSnapshot {
                        LoggerService.shared.info("Toolbar 'Restore' clicked for snapshot: \(snapshot.name)", category: "SnapshotListView")
                        Task { await snapshotViewModel.restoreSnapshot(snapshot) }
                    }
                } label: {
                    Label("Restore", systemImage: "arrow.counterclockwise")
                }
                .disabled(snapshotViewModel.selectedSnapshot == nil || snapshotViewModel.isRestoring)
                
                Button(role: .destructive) {
                    if let snapshot = snapshotViewModel.selectedSnapshot {
                        LoggerService.shared.info("Toolbar 'Delete' clicked for snapshot: \(snapshot.name)", category: "SnapshotListView")
                        Task { await snapshotViewModel.deleteSnapshot(snapshot) }
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(snapshotViewModel.selectedSnapshot == nil)
            }
        }
    }
    
    @ViewBuilder
    private func snapshotContextMenu(for snapshot: Snapshot) -> some View {
        Button {
            LoggerService.shared.info("Context menu 'Restore' selected for snapshot: \(snapshot.name)", category: "SnapshotListView")
            Task { await snapshotViewModel.restoreSnapshot(snapshot) }
        } label: {
            Label("Restore", systemImage: "arrow.counterclockwise")
        }
        
        Divider()
        
        Button(role: .destructive) {
            LoggerService.shared.info("Context menu 'Delete' selected for snapshot: \(snapshot.name)", category: "SnapshotListView")
            Task { await snapshotViewModel.deleteSnapshot(snapshot) }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    private func handleSelectionChange(_ newValue: Snapshot?) {
        if let snapshot = newValue {
            LoggerService.shared.info("Snapshot selected: \(snapshot.name)", category: "SnapshotListView")
            LoggerService.shared.debug("Selected snapshot details - windows: \(snapshot.windowCount), displays: \(snapshot.displayCount)", category: "SnapshotListView")
        } else {
            LoggerService.shared.info("Snapshot selection cleared", category: "SnapshotListView")
        }
    }
    
    @ViewBuilder
    private var emptyOverlay: some View {
        if snapshotViewModel.snapshots.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                Text("No Snapshots")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Text("Save a snapshot to preserve your current window layout")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button("Save Snapshot") {
                    snapshotViewModel.showSaveSheet = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - SnapshotCard

struct SnapshotCard: View {
    let snapshot: Snapshot
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(snapshot.name)
                    .font(.headline)
                
                Spacer()
                
                Text(snapshot.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !snapshot.description.isEmpty {
                Text(snapshot.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack(spacing: 16) {
                Label("\(snapshot.windowCount) windows", systemImage: "rectangle.on.rectangle")
                    .font(.caption)
                
                Label("\(snapshot.displayCount) displays", systemImage: "display")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(snapshot.uniqueAppNames.prefix(5), id: \.self) { appName in
                        AppBadge(name: appName)
                    }
                    
                    if snapshot.uniqueAppNames.count > 5 {
                        Text("+\(snapshot.uniqueAppNames.count - 5) more")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - AppBadge

struct AppBadge: View {
    let name: String
    
    var body: some View {
        Text(name)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.1))
            .foregroundColor(.primary)
            .cornerRadius(4)
    }
}

// MARK: - Preview
