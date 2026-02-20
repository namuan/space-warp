//
//  AppDelegate.swift
//  SpaceWarp
//
//  Application delegate handling menu bar and lifecycle events.
//

import AppKit
import SwiftUI

// MARK: - AppDelegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties
    
    private var statusItem: NSStatusItem?
    private let dependencyContainer = DependencyContainer.shared
    private var snapshotMenuItems: [NSMenuItem] = []
    
    // MARK: - Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupHotkeys()
        checkLaunchOptions()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.unregisterAll()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }
    
    // MARK: - Menu Bar Setup
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let button = statusItem?.button else { return }
        
        button.image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: "SpaceWarp")
        button.toolTip = "SpaceWarp - Window Layout Manager"
        
        let menu = createMenuBarMenu()
        statusItem?.menu = menu
        
        // Observe snapshot changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateSnapshotMenuItems),
            name: .snapshotsDidChange,
            object: nil
        )
    }
    
    private func createMenuBarMenu() -> NSMenu {
        let menu = NSMenu()
        
        // Quick actions
        let saveItem = NSMenuItem(
            title: "Save Snapshot",
            action: #selector(saveSnapshot),
            keyEquivalent: "s"
        )
        saveItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(saveItem)
        
        let restoreItem = NSMenuItem(
            title: "Restore Last Snapshot",
            action: #selector(restoreLastSnapshot),
            keyEquivalent: "r"
        )
        restoreItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(restoreItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Recent snapshots section
        let snapshotsHeader = NSMenuItem(title: "Recent Snapshots", action: nil, keyEquivalent: "")
        snapshotsHeader.isEnabled = false
        menu.addItem(snapshotsHeader)
        
        // Placeholder for snapshot items
        let noSnapshotsItem = NSMenuItem(title: "No snapshots saved", action: nil, keyEquivalent: "")
        noSnapshotsItem.isEnabled = false
        noSnapshotsItem.tag = 999
        menu.addItem(noSnapshotsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // App controls
        menu.addItem(
            NSMenuItem(title: "Show Window", action: #selector(showMainWindow), keyEquivalent: "m")
        )
        menu.addItem(
            NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        )
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(
            NSMenuItem(title: "Quit SpaceWarp", action: #selector(quitApp), keyEquivalent: "q")
        )
        
        return menu
    }
    
    @objc
    private func updateSnapshotMenuItems() {
        guard let menu = statusItem?.menu else { return }
        
        // Remove existing snapshot items
        for item in snapshotMenuItems {
            menu.removeItem(item)
        }
        snapshotMenuItems.removeAll()
        
        // Get current snapshots
        let snapshots = dependencyContainer.snapshotViewModel.snapshots
        
        if snapshots.isEmpty {
            return
        }
        
        // Find the "No snapshots" placeholder and remove it
        if let placeholderIndex = menu.items.firstIndex(where: { $0.tag == 999 }) {
            menu.removeItem(at: placeholderIndex)
        }
        
        // Add snapshot items after header (index 3)
        var insertIndex = 3
        for snapshot in snapshots.prefix(5) {
            let item = NSMenuItem(
                title: snapshot.name,
                action: #selector(restoreSnapshot(_:)),
                keyEquivalent: ""
            )
            item.representedObject = snapshot
            menu.insertItem(item, at: insertIndex)
            snapshotMenuItems.append(item)
            insertIndex += 1
        }
    }
    
    // MARK: - Hotkey Setup
    
    private func setupHotkeys() {
        let hotkeyManager = HotkeyManager.shared
        let settings = dependencyContainer.settingsViewModel.settings
        
        // Save snapshot hotkey
        hotkeyManager.registerHotkey(
            keyCombo: settings.hotkeys.saveSnapshot
        ) { [weak self] in
            self?.saveSnapshot()
        }
        
        // Restore last snapshot hotkey
        hotkeyManager.registerHotkey(
            keyCombo: settings.hotkeys.restoreLastSnapshot
        ) { [weak self] in
            self?.restoreLastSnapshot()
        }
        
        // Toggle window manager hotkey
        hotkeyManager.registerHotkey(
            keyCombo: settings.hotkeys.toggleWindowManager
        ) { [weak self] in
            self?.showMainWindow()
        }
    }
    
    // MARK: - Launch Options
    
    private func checkLaunchOptions() {
        let settings = dependencyContainer.settingsViewModel.settings
        
        // Start minimized if configured
        if settings.startMinimized {
            NSApp.hide(nil)
        }
    }
    
    // MARK: - Actions
    
    @objc
    func saveSnapshot() {
        Task { @MainActor in
            await dependencyContainer.snapshotViewModel.saveQuickSnapshot()
        }
    }
    
    @objc
    func restoreLastSnapshot() {
        Task { @MainActor in
            await dependencyContainer.snapshotViewModel.restoreLastSnapshot()
        }
    }
    
    @objc
    func restoreSnapshot(_ sender: NSMenuItem) {
        guard let snapshot = sender.representedObject as? Snapshot else { return }
        
        Task { @MainActor in
            await dependencyContainer.snapshotViewModel.restoreSnapshot(snapshot)
        }
    }
    
    @objc
    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        
        if let window = NSApp.windows.first(where: { $0.contentView?.subviews.first is NSHostingView<ContentView> }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc
    func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
    
    @objc
    func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let snapshotsDidChange = Notification.Name("com.spacewarp.snapshotsDidChange")
}
