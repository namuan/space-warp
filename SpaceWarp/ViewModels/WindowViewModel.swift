//
//  WindowViewModel.swift
//  SpaceWarp
//
//  View model for window list management.
//

import AppKit
import Combine
import Foundation

// MARK: - WindowViewModel

/// Manages the state of current windows view.
@MainActor
final class WindowViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var windows: [WindowInfo] = []
    @Published private(set) var displays: [DisplayInfo] = []
    @Published private(set) var isLoading = false
    @Published private(set) var filterAppName: String?
    @Published var selectedWindow: WindowInfo?
    
    // MARK: - Private Properties
    
    private let windowManager: WindowManager
    private var refreshTask: Task<Void, Never>?
    
    // MARK: - Computed Properties
    
    var windowCount: Int { windows.count }
    var displayCount: Int { displays.count }
    
    var uniqueAppNames: [String] {
        Array(Set(windows.map(\.appName))).sorted()
    }
    
    var windowsByApp: [String: [WindowInfo]] {
        Dictionary(grouping: windows, by: \.appName)
    }
    
    // MARK: - Initialization
    
    init(windowManager: WindowManager) {
        self.windowManager = windowManager
    }
    
    // MARK: - Public Methods
    
    /// Refreshes the window and display lists
    func refresh() {
        refreshTask?.cancel()
        
        refreshTask = Task {
            isLoading = true
            defer { isLoading = false }
            
            async let windowsTask = windowManager.getWindows(filterByApp: filterAppName)
            async let displaysTask = windowManager.getDisplays()
            
            windows = await windowsTask
            displays = await displaysTask
        }
    }
    
    /// Captures all current windows
    func captureAll() {
        filterAppName = nil
        refresh()
    }
    
    /// Filters windows by application name
    /// - Parameter appName: Application name to filter by
    func filter(byAppName appName: String?) {
        filterAppName = appName
        refresh()
    }
    
    /// Clears the filter
    func clearFilter() {
        filterAppName = nil
        refresh()
    }
    
    /// Gets windows on a specific display
    /// - Parameter displayId: Display ID
    /// - Returns: Windows on that display
    func windows(onDisplay displayId: Int) -> [WindowInfo] {
        windows.filter { $0.displayId == displayId }
    }
    
    /// Gets the display info for a window
    /// - Parameter window: Window to look up
    /// - Returns: Display info if found
    func display(for window: WindowInfo) -> DisplayInfo? {
        displays.first { $0.displayId == window.displayId }
    }
}
