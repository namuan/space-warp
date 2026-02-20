//
//  PermissionView.swift
//  SpaceWarp
//
//  Permission request and status view.
//

import AppKit
import SwiftUI

// MARK: - PermissionView

struct PermissionView: View {
    @EnvironmentObject var permissionManager: PermissionManager
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)
                
                Text("Permissions Required")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Text("SpaceWarp needs these permissions to manage your windows")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Divider()
            
            // Permission list
            VStack(spacing: 16) {
                PermissionRow(
                    type: .accessibility,
                    isGranted: permissionManager.accessibilityGranted
                ) {
                    Task { _ = await permissionManager.requestAccessibilityPermission() }
                }
                
                PermissionRow(
                    type: .screenRecording,
                    isGranted: permissionManager.screenRecordingGranted
                ) {
                    Task { _ = await permissionManager.requestScreenRecordingPermission() }
                }
                
                PermissionRow(
                    type: .automation,
                    isGranted: permissionManager.automationGranted
                ) {
                    Task { _ = await permissionManager.requestAutomationPermission() }
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            // Actions
            VStack(spacing: 12) {
                Button("Open System Settings") {
                    permissionManager.openAccessibilitySettings()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("Check Again") {
                    Task { await permissionManager.checkPermissions() }
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: 500, maxHeight: 600)
    }
}

// MARK: - PermissionRow

struct PermissionRow: View {
    let type: PermissionType
    let isGranted: Bool
    let onRequest: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: type.systemImage)
                .font(.title2)
                .foregroundColor(isGranted ? .green : .orange)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(type.displayName)
                    .font(.headline)
                
                Text(type.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            } else {
                Button("Grant") {
                    onRequest()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    PermissionView()
        .environmentObject(PermissionManager())
}
