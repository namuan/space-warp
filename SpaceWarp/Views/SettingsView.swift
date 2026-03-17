//
//  SettingsView.swift
//  SpaceWarp
//
//  Application settings window.
//

import AppKit
import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            
            HotkeySettingsView()
                .tabItem {
                    Label("Hotkeys", systemImage: "keyboard")
                }
            
            DisplaySettingsView()
                .tabItem {
                    Label("Displays", systemImage: "display")
                }
            
            SnapshotSettingsView()
                .tabItem {
                    Label("Snapshots", systemImage: "camera")
                }
            
            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - GeneralSettingsView

struct GeneralSettingsView: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        Form {
            Section {
                Toggle("Start minimized", isOn: Binding(
                    get: { settingsViewModel.settings.startMinimized },
                    set: { settingsViewModel.updateStartMinimized($0) }
                ))
                
                Toggle("Launch at login", isOn: Binding(
                    get: { settingsViewModel.settings.autoStart },
                    set: { settingsViewModel.updateAutoStart($0) }
                ))
                
                Toggle("Show in menu bar", isOn: Binding(
                    get: { settingsViewModel.settings.showInMenuBar },
                    set: { settingsViewModel.updateShowInMenuBar($0) }
                ))
            } header: {
                Text("Startup")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - HotkeySettingsView

struct HotkeySettingsView: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Save Snapshot")
                    Spacer()
                    HotkeyRecorder(
                        value: settingsViewModel.settings.hotkeys.saveSnapshot,
                        onChange: { settingsViewModel.updateSaveSnapshotHotkey($0) }
                    )
                }
                
                HStack {
                    Text("Restore Last Snapshot")
                    Spacer()
                    HotkeyRecorder(
                        value: settingsViewModel.settings.hotkeys.restoreLastSnapshot,
                        onChange: { settingsViewModel.updateRestoreLastSnapshotHotkey($0) }
                    )
                }
                
                HStack {
                    Text("Toggle Window Manager")
                    Spacer()
                    HotkeyRecorder(
                        value: settingsViewModel.settings.hotkeys.toggleWindowManager,
                        onChange: { settingsViewModel.updateToggleWindowManagerHotkey($0) }
                    )
                }
            } header: {
                Text("Keyboard Shortcuts")
            } footer: {
                Text("Click on a shortcut to record a new key combination")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - HotkeyRecorder

struct HotkeyRecorder: View {
    let value: String
    let onChange: (String) -> Void
    
    @State private var isRecording = false
    
    var body: some View {
        Button {
            isRecording = true
            // In a real implementation, this would capture key events
        } label: {
            Text(value)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isRecording ? Color.accentColor : Color.secondary.opacity(0.2))
                .foregroundColor(isRecording ? .white : .primary)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - DisplaySettingsView

struct DisplaySettingsView: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        Form {
            Section {
                Toggle("Auto-adjust for missing displays", isOn: Binding(
                    get: { settingsViewModel.settings.display.autoAdjustMissingDisplays },
                    set: { settingsViewModel.updateAutoAdjustMissingDisplays($0) }
                ))
                
                Toggle("Prompt when displays are missing", isOn: Binding(
                    get: { settingsViewModel.settings.display.promptForMissingDisplays },
                    set: { settingsViewModel.updatePromptForMissingDisplays($0) }
                ))
                
                Toggle("Remember display assignments", isOn: Binding(
                    get: { settingsViewModel.settings.display.rememberDisplayAssignments },
                    set: { settingsViewModel.settings.display.rememberDisplayAssignments = $0; settingsViewModel.settings.display.rememberDisplayAssignments = $0 }
                ))
            } header: {
                Text("Display Configuration")
            } footer: {
                Text("These settings control how SpaceWarp handles display configuration changes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - SnapshotSettingsView

struct SnapshotSettingsView: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        Form {
            Section {
                Picker("Auto-save interval", selection: Binding(
                    get: { settingsViewModel.settings.snapshots.autoSaveInterval },
                    set: { settingsViewModel.updateAutoSaveInterval($0) }
                )) {
                    Text("Disabled").tag(0)
                    Text("Every 1 minute").tag(60)
                    Text("Every 5 minutes").tag(300)
                    Text("Every 15 minutes").tag(900)
                    Text("Every 30 minutes").tag(1800)
                }
                
                Stepper("Maximum snapshots: \(settingsViewModel.settings.snapshots.maxSnapshots)", value: Binding(
                    get: { settingsViewModel.settings.snapshots.maxSnapshots },
                    set: { settingsViewModel.updateMaxSnapshots($0) }
                ), in: 10...100, step: 10)
                
                Toggle("Confirm before restore", isOn: Binding(
                    get: { settingsViewModel.settings.snapshots.confirmBeforeRestore },
                    set: { settingsViewModel.updateConfirmBeforeRestore($0) }
                ))
                
                Toggle("Show restore report", isOn: Binding(
                    get: { settingsViewModel.settings.snapshots.showRestoreReport },
                    set: { settingsViewModel.updateShowRestoreReport($0) }
                ))
            } header: {
                Text("Snapshot Management")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - AdvancedSettingsView

struct AdvancedSettingsView: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        Form {
            Section {
                Toggle("Debug mode", isOn: Binding(
                    get: { settingsViewModel.settings.debugMode },
                    set: { settingsViewModel.updateDebugMode($0) }
                ))
                
                Picker("Log level", selection: Binding(
                    get: { settingsViewModel.settings.logLevel },
                    set: { settingsViewModel.updateLogLevel($0) }
                )) {
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }
            } header: {
                Text("Developer Options")
            } footer: {
                Text("These options are intended for troubleshooting and development")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section {
                Button("Reset All Settings") {
                    settingsViewModel.resetToDefaults()
                }
            } header: {
                Text("Reset")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Preview

#if canImport(DeveloperToolsSupport)
#Preview {
    SettingsView()
        .environmentObject(SettingsViewModel(configManager: ConfigManager()))
}
#endif
