//
//  WindowListView.swift
//  SpaceWarp
//
//  Displays the list of current windows.
//

import AppKit
import SwiftUI

// MARK: - WindowListView

struct WindowListView: View {
    @EnvironmentObject var windowViewModel: WindowViewModel
    @EnvironmentObject var permissionManager: PermissionManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            HStack {
                if windowViewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                    Text("\(windowViewModel.windowCount) windows")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    windowViewModel.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Window list
            if windowViewModel.windows.isEmpty && !windowViewModel.isLoading {
                emptyStateView
            } else {
                windowListContent
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.on.rectangle.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Windows Captured")
                .font(.title2)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("Make sure:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Label("Accessibility permission is granted", systemImage: permissionManager.accessibilityGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(permissionManager.accessibilityGranted ? .green : .red)
                        .font(.caption)
                    
                    Label("You have visible windows open", systemImage: "rectangle.on.rectangle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("Click Refresh to try again", systemImage: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            Button("Refresh") {
                windowViewModel.refresh()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var windowListContent: some View {
        List(selection: $windowViewModel.selectedWindow) {
            ForEach(groupedWindows.keys.sorted(), id: \.self) { appName in
                Section(header: 
                    HStack {
                        Text(appName)
                        Spacer()
                        Text("\(groupedWindows[appName]?.count ?? 0)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                ) {
                    ForEach(groupedWindows[appName] ?? []) { window in
                        WindowRow(window: window)
                            .tag(window)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
    
    private var groupedWindows: [String: [WindowInfo]] {
        windowViewModel.windowsByApp
    }
}

// MARK: - WindowRow

struct WindowRow: View {
    let window: WindowInfo
    @EnvironmentObject var windowViewModel: WindowViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // App icon
            if let app = NSRunningApplication(processIdentifier: window.pid) {
                Image(nsImage: app.icon ?? NSImage())
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "app.fill")
                    .frame(width: 24, height: 24)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(window.windowTitle.isEmpty ? "Untitled" : window.windowTitle)
                    .font(.body)
                    .lineLimit(1)
                
                Text("\(window.width)×\(window.height) at (\(window.x), \(window.y))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Display badge
            if let displayName = windowViewModel.displayNameForDisplay(window.displayId) {
                DisplayBadge(name: displayName)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - DisplayBadge

struct DisplayBadge: View {
    let name: String
    
    var body: some View {
        Text(name)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.2))
            .cornerRadius(4)
    }
}

// MARK: - WindowViewModel Extension

extension WindowViewModel {
    func displayNameForDisplay(_ displayId: Int) -> String? {
        displays.first { $0.displayId == displayId }?.name
    }
}

