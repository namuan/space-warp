//
//  HotkeyManager.swift
//  SpaceWarp
//
//  Global keyboard shortcut management using CGEvent.
//

import AppKit
import Combine
import CoreGraphics
import Foundation

// MARK: - HotkeyManager

/// Manages global keyboard shortcuts using CGEvent tap.
@MainActor
final class HotkeyManager: ObservableObject {
    // MARK: - Singleton
    
    static let shared = HotkeyManager()
    
    // MARK: - Properties
    
    private var registeredHotkeys: [HotkeyIdentifier: Hotkey] = [:]
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isMonitoring = false
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Starts the event tap for global hotkey monitoring
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon!).takeUnretainedValue()
                
                if type == .keyDown {
                    Task { @MainActor in
                        manager.handleKeyEvent(event: event)
                    }
                }
                
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            isMonitoring = true
        }
    }
    
    /// Stops the event tap
    func stopMonitoring() {
        guard isMonitoring, let tap = eventTap else { return }
        
        CGEvent.tapEnable(tap: tap, enable: false)
        
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        
        eventTap = nil
        runLoopSource = nil
        isMonitoring = false
    }
    
    /// Registers a global hotkey
    /// - Parameters:
    ///   - keyCombo: Key combination string (e.g., "⌃⇧S")
    ///   - action: Action to perform when triggered
    func registerHotkey(keyCombo: String, action: @escaping () -> Void) {
        guard let (modifiers, keyCode) = parseKeyCombo(keyCombo) else { return }
        
        let hotkey = Hotkey(
            modifiers: modifiers,
            keyCode: keyCode,
            action: action
        )
        
        // Find identifier for this combo
        if let identifier = HotkeyIdentifier.allCases.first(where: { $0.defaultKeyCombo == keyCombo }) {
            registeredHotkeys[identifier] = hotkey
        } else {
            // Store with a generated identifier
            let identifier = HotkeyIdentifier.saveSnapshot
            registeredHotkeys[identifier] = hotkey
        }
        
        // Start monitoring if not already
        startMonitoring()
    }
    
    /// Registers a hotkey by identifier
    /// - Parameters:
    ///   - identifier: Hotkey identifier
    ///   - action: Action to perform
    func register(identifier: HotkeyIdentifier, action: @escaping () -> Void) {
        let (modifiers, keyCode) = parseKeyCombo(identifier.defaultKeyCombo)!
        registeredHotkeys[identifier] = Hotkey(
            modifiers: modifiers,
            keyCode: keyCode,
            action: action
        )
        startMonitoring()
    }
    
    /// Unregisters a hotkey
    /// - Parameter identifier: Hotkey identifier
    func unregister(identifier: HotkeyIdentifier) {
        registeredHotkeys.removeValue(forKey: identifier)
        
        if registeredHotkeys.isEmpty {
            stopMonitoring()
        }
    }
    
    /// Unregisters all hotkeys
    func unregisterAll() {
        registeredHotkeys.removeAll()
        stopMonitoring()
    }
    
    /// Checks if a hotkey is registered
    /// - Parameter identifier: Hotkey identifier
    /// - Returns: Whether the hotkey is registered
    func isRegistered(_ identifier: HotkeyIdentifier) -> Bool {
        registeredHotkeys[identifier] != nil
    }
    
    // MARK: - Private Methods
    
    private func handleKeyEvent(event: CGEvent) {
        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        // Convert CGEventFlags to NSEvent.ModifierFlags
        var modifiers: NSEvent.ModifierFlags = []
        if flags.contains(.maskControl) { modifiers.insert(.control) }
        if flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if flags.contains(.maskShift) { modifiers.insert(.shift) }
        if flags.contains(.maskCommand) { modifiers.insert(.command) }
        
        // Check if any registered hotkey matches
        for (identifier, hotkey) in registeredHotkeys {
            if hotkey.keyCode == UInt16(keyCode) && hotkey.modifiers == modifiers {
                hotkey.action()
                return
            }
        }
    }
    
    private func parseKeyCombo(_ combo: String) -> (NSEvent.ModifierFlags, UInt16)? {
        var modifiers: NSEvent.ModifierFlags = []
        var key = combo
        
        if key.contains("⌃") {
            modifiers.insert(.control)
            key = key.replacingOccurrences(of: "⌃", with: "")
        }
        if key.contains("⌥") {
            modifiers.insert(.option)
            key = key.replacingOccurrences(of: "⌥", with: "")
        }
        if key.contains("⇧") {
            modifiers.insert(.shift)
            key = key.replacingOccurrences(of: "⇧", with: "")
        }
        if key.contains("⌘") {
            modifiers.insert(.command)
            key = key.replacingOccurrences(of: "⌘", with: "")
        }
        
        key = key.trimmingCharacters(in: .whitespaces)
        
        guard let keyCode = keyToKeyCode(key) else { return nil }
        return (modifiers, keyCode)
    }
    
    private func keyToKeyCode(_ key: String) -> UInt16? {
        let keyMap: [String: UInt16] = [
            "A": 0x00, "S": 0x01, "D": 0x02, "F": 0x03,
            "H": 0x04, "G": 0x05, "Z": 0x06, "X": 0x07,
            "C": 0x08, "V": 0x09, "B": 0x0B, "Q": 0x0C,
            "W": 0x0D, "E": 0x0E, "R": 0x0F, "Y": 0x10,
            "T": 0x11, "1": 0x12, "2": 0x13, "3": 0x14,
            "4": 0x15, "6": 0x16, "5": 0x17, "=": 0x18,
            "9": 0x19, "7": 0x1A, "-": 0x1B, "8": 0x1C,
            "0": 0x1D, "]": 0x1E, "O": 0x1F, "U": 0x20,
            "[": 0x21, "I": 0x22, "P": 0x23, "L": 0x25,
            "J": 0x26, "'": 0x27, "K": 0x28, ";": 0x29,
            "\\": 0x2A, ",": 0x2B, "/": 0x2C, "N": 0x2D,
            "M": 0x2E, ".": 0x2F, "`": 0x32,
            "Return": 0x24, "Tab": 0x30, "Space": 0x31,
            "Delete": 0x33, "Escape": 0x35
        ]
        
        return keyMap[key.uppercased()] ?? keyMap[key]
    }
}

// MARK: - Hotkey

private struct Hotkey {
    let modifiers: NSEvent.ModifierFlags
    let keyCode: UInt16
    let action: () -> Void
}

// MARK: - HotkeyIdentifier

enum HotkeyIdentifier: String, CaseIterable {
    case saveSnapshot = "saveSnapshot"
    case restoreLastSnapshot = "restoreLastSnapshot"
    case toggleWindowManager = "toggleWindowManager"
    
    var defaultKeyCombo: String {
        switch self {
        case .saveSnapshot: return "⌃⇧S"
        case .restoreLastSnapshot: return "⌃⇧R"
        case .toggleWindowManager: return "⌃⇧M"
        }
    }
}
