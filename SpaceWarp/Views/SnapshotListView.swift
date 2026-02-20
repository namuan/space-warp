//
//  SnapshotListView.swift
//  SpaceWarp
//
//  Displays and manages saved snapshots.
//

import AppKit
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
                        Button {
                            Task { await snapshotViewModel.restoreSnapshot(snapshot) }
                        } label: {
                            Label("Restore", systemImage: "arrow.counterclockwise")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            Task { await snapshotViewModel.deleteSnapshot(snapshot) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.inset)
        .overlay {
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
        .toolbar {
            ToolbarItemGroup {
                Button {
                    if let snapshot = snapshotViewModel.selectedSnapshot {
                        Task { await snapshotViewModel.restoreSnapshot(snapshot) }
                    }
                } label: {
                    Label("Restore", systemImage: "arrow.counterclockwise")
                }
                .disabled(snapshotViewModel.selectedSnapshot == nil || snapshotViewModel.isRestoring)
                
                Button(role: .destructive) {
                    if let snapshot = snapshotViewModel.selectedSnapshot {
                        Task { await snapshotViewModel.deleteSnapshot(snapshot) }
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(snapshotViewModel.selectedSnapshot == nil)
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
            
            // App badges
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

#Preview {
    SnapshotListView()
        .frame(width: 500, height: 600)
        .environmentObject(SnapshotViewModel(
            snapshotManager: SnapshotManager(configManager: ConfigManager()),
            windowManager: WindowManager()
        ))
}
