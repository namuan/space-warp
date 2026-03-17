import Foundation
import SwiftUI

struct SnapshotDetailView: View {
    let snapshot: Snapshot
    let onBack: () -> Void
    
    @EnvironmentObject private var snapshotViewModel: SnapshotViewModel
    @State private var appToDelete: String?
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    private var windowsGroupedByApp: [String: [WindowInfo]] {
        Dictionary(grouping: snapshot.windows, by: \.appName)
    }
    
    private var sortedAppNames: [String] {
        windowsGroupedByApp.keys.sorted()
    }
    
    init(snapshot: Snapshot, onBack: @escaping () -> Void) {
        self.snapshot = snapshot
        self.onBack = onBack
        LoggerService.shared.info("SnapshotDetailView initializing", category: "SnapshotDetailView")
    }
    
    private func logSnapshotData() {
        LoggerService.shared.info("Displaying snapshot: \(snapshot.name)", category: "SnapshotDetailView")
        LoggerService.shared.debug("Snapshot details - windowCount: \(snapshot.windowCount), displayCount: \(snapshot.displayCount), createdAt: \(snapshot.createdAt)", category: "SnapshotDetailView")
        LoggerService.shared.debug("App names: \(sortedAppNames.joined(separator: ", "))", category: "SnapshotDetailView")
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                
                if snapshot.windows.isEmpty {
                    emptyStateView
                } else {
                    appsListView
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear {
            logSnapshotData()
        }
        .alert("Remove App", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                appToDelete = nil
            }
            Button("Remove", role: .destructive) {
                if let appName = appToDelete {
                    Task {
                        await removeApp(appName)
                    }
                }
            }
        } message: {
            if let appName = appToDelete {
                Text("Are you sure you want to remove all windows from \"\(appName)\"? This cannot be undone.")
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .disabled(isDeleting)
        .overlay {
            if isDeleting {
                ProgressView("Removing app...")
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(8)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: {
                    LoggerService.shared.info("Clear selection button clicked, calling onBack callback", category: "SnapshotDetailView")
                    onBack()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle")
                        Text("Clear Selection")
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Spacer()
            }
            
            Text(snapshot.name)
                .font(.title2)
                .fontWeight(.bold)
            
            if !snapshot.description.isEmpty {
                Text(snapshot.description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                Label {
                    Text(snapshot.createdAt, style: .date)
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Label {
                    Text("\(snapshot.windowCount) windows")
                } icon: {
                    Image(systemName: "rectangle.on.rectangle")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Label {
                    Text("\(sortedAppNames.count) apps")
                } icon: {
                    Image(systemName: "app")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.bottom, 8)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Windows in Snapshot")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("This snapshot doesn't contain any windows. Create a new snapshot to capture your current window layout.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var appsListView: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(sortedAppNames, id: \.self) { appName in
                AppSectionView(
                    appName: appName,
                    windows: windowsGroupedByApp[appName] ?? [],
                    onRemove: {
                        LoggerService.shared.info("Remove button clicked for app: \(appName)", category: "SnapshotDetailView")
                        appToDelete = appName
                        showingDeleteConfirmation = true
                    }
                )
            }
        }
    }
    
    private func removeApp(_ appName: String) async {
        LoggerService.shared.info("Starting removeApp for app: \(appName) from snapshot: \(snapshot.name)", category: "SnapshotDetailView")
        isDeleting = true
        defer { 
            isDeleting = false
            LoggerService.shared.debug("removeApp completed for app: \(appName)", category: "SnapshotDetailView")
        }
        
        await snapshotViewModel.removeApp(appName: appName, from: snapshot)
        
        if let error = snapshotViewModel.errorMessage {
            LoggerService.shared.error("Failed to remove app \(appName): \(error)", category: "SnapshotDetailView")
            errorMessage = error
            showingError = true
        } else {
            LoggerService.shared.info("Successfully removed app: \(appName), calling onBack", category: "SnapshotDetailView")
            onBack()
        }
        
        appToDelete = nil
    }
}

struct AppSectionView: View {
    let appName: String
    let windows: [WindowInfo]
    let onRemove: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "app.fill")
                    .foregroundColor(.accentColor)
                
                Text(appName)
                    .font(.headline)
                
                Spacer()
                
                Button(role: .destructive, action: onRemove) {
                    Text("Remove App")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            VStack(spacing: 0) {
                ForEach(Array(windows.enumerated()), id: \.element.id) { index, window in
                    WindowRowView(window: window)
                    
                    if index < windows.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }
}

struct WindowRowView: View {
    let window: WindowInfo
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(window.windowTitle.isEmpty ? "Untitled Window" : window.windowTitle)
                    .font(.subheadline)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    Label {
                        Text("Position: (\(window.x), \(window.y))")
                    } icon: {
                        Image(systemName: "arrow.up.left")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Label {
                        Text("Size: \(window.width)×\(window.height)")
                    } icon: {
                        Image(systemName: "arrow.up.right.and.arrow.down.left")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    if window.isMinimized {
                        Label("Minimized", systemImage: "minus.circle")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    
                    if window.isHidden {
                        Label("Hidden", systemImage: "eye.slash")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Label("Display \(window.displayId)", systemImage: "display")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#if canImport(DeveloperToolsSupport)
#Preview {
    let sampleSnapshot = Snapshot(
        id: UUID(),
        name: "Development Setup",
        description: "My coding workspace with Xcode and Terminal",
        createdAt: Date(),
        windows: [
            WindowInfo(
                id: UUID(),
                appName: "Xcode",
                windowTitle: "SpaceWarp - SnapshotManager.swift",
                x: 0,
                y: 0,
                width: 1920,
                height: 1080,
                isMinimized: false,
                isHidden: false,
                displayId: 1,
                pid: 12345,
                bundleId: "com.apple.dt.Xcode",
                spaceId: 1,
                windowId: 100
            ),
            WindowInfo(
                id: UUID(),
                appName: "Xcode",
                windowTitle: "SnapshotDetailView.swift",
                x: 100,
                y: 100,
                width: 800,
                height: 600,
                isMinimized: false,
                isHidden: false,
                displayId: 1,
                pid: 12345,
                bundleId: "com.apple.dt.Xcode",
                spaceId: 1,
                windowId: 101
            ),
            WindowInfo(
                id: UUID(),
                appName: "Terminal",
                windowTitle: "bash - ~/workspace/space-warp",
                x: 1920,
                y: 0,
                width: 800,
                height: 1080,
                isMinimized: false,
                isHidden: false,
                displayId: 2,
                pid: 23456,
                bundleId: "com.apple.Terminal",
                spaceId: 1,
                windowId: 200
            ),
            WindowInfo(
                id: UUID(),
                appName: "Safari",
                windowTitle: "SwiftUI Documentation",
                x: 500,
                y: 200,
                width: 1200,
                height: 800,
                isMinimized: true,
                isHidden: false,
                displayId: 1,
                pid: 34567,
                bundleId: "com.apple.Safari",
                spaceId: 1,
                windowId: 300
            )
        ],
        displays: [],
        metadata: [:]
    )
    
    let emptySnapshot = Snapshot(
        id: UUID(),
        name: "Empty Snapshot",
        description: "A snapshot with no windows",
        createdAt: Date(),
        windows: [],
        displays: [],
        metadata: [:]
    )
    
    Group {
        SnapshotDetailView(
            snapshot: sampleSnapshot,
            onBack: { print("Back tapped") }
        )
        .environmentObject(SnapshotViewModel(
            snapshotManager: SnapshotManager(configManager: ConfigManager()),
            windowManager: WindowManager()
        ))
        
        SnapshotDetailView(
            snapshot: emptySnapshot,
            onBack: { print("Back tapped") }
        )
        .environmentObject(SnapshotViewModel(
            snapshotManager: SnapshotManager(configManager: ConfigManager()),
            windowManager: WindowManager()
        ))
    }
}
#endif
