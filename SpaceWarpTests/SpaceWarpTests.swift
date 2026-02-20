//
//  SpaceWarpTests.swift
//  SpaceWarpTests
//
//  Unit tests for SpaceWarp.
//

@testable import SpaceWarp
import XCTest

// MARK: - WindowInfoTests

final class WindowInfoTests: XCTestCase {
    
    func testWindowInfoInitialization() {
        let window = WindowInfo(
            appName: "Safari",
            windowTitle: "GitHub",
            x: 100,
            y: 200,
            width: 800,
            height: 600,
            isMinimized: false,
            isHidden: false,
            displayId: 1,
            pid: 12345,
            bundleId: "com.apple.Safari",
            spaceId: nil,
            windowId: 42
        )
        
        XCTAssertEqual(window.appName, "Safari")
        XCTAssertEqual(window.windowTitle, "GitHub")
        XCTAssertEqual(window.width, 800)
        XCTAssertEqual(window.height, 600)
        XCTAssertTrue(window.isValid)
    }
    
    func testWindowRect() {
        let window = WindowInfo(
            appName: "Test",
            windowTitle: "",
            x: 100,
            y: 200,
            width: 800,
            height: 600,
            isMinimized: false,
            isHidden: false,
            displayId: 1,
            pid: 1,
            bundleId: nil,
            spaceId: nil,
            windowId: nil
        )
        
        XCTAssertEqual(window.rect.origin.x, 100)
        XCTAssertEqual(window.rect.origin.y, 200)
        XCTAssertEqual(window.rect.width, 800)
        XCTAssertEqual(window.rect.height, 600)
    }
    
    func testInvalidWindow() {
        let invalidWindow = WindowInfo(
            appName: "",
            windowTitle: "",
            x: 0,
            y: 0,
            width: 0,
            height: 0,
            isMinimized: false,
            isHidden: false,
            displayId: 0,
            pid: 0,
            bundleId: nil,
            spaceId: nil,
            windowId: nil
        )
        
        XCTAssertFalse(invalidWindow.isValid)
    }
}

// MARK: - DisplayInfoTests

final class DisplayInfoTests: XCTestCase {
    
    func testDisplayInfoInitialization() {
        let display = DisplayInfo(
            displayId: 1,
            name: "Built-in Retina Display",
            width: 2560,
            height: 1600,
            x: 0,
            y: 0,
            isMain: true
        )
        
        XCTAssertEqual(display.name, "Built-in Retina Display")
        XCTAssertTrue(display.isMain)
        XCTAssertEqual(display.width, 2560)
    }
    
    func testDisplayContainsPoint() {
        let display = DisplayInfo(
            displayId: 1,
            name: "Main",
            width: 1920,
            height: 1080,
            x: 0,
            y: 0,
            isMain: true
        )
        
        XCTAssertTrue(display.contains(point: CGPoint(x: 500, y: 500)))
        XCTAssertFalse(display.contains(point: CGPoint(x: 2000, y: 500)))
    }
    
    func testDisplayIntersection() {
        let display = DisplayInfo(
            displayId: 1,
            name: "Main",
            width: 1920,
            height: 1080,
            x: 0,
            y: 0,
            isMain: true
        )
        
        let intersectingRect = CGRect(x: 1800, y: 0, width: 200, height: 500)
        XCTAssertTrue(display.intersects(rect: intersectingRect))
        
        let nonIntersectingRect = CGRect(x: 2000, y: 0, width: 200, height: 500)
        XCTAssertFalse(display.intersects(rect: nonIntersectingRect))
    }
}

// MARK: - SnapshotTests

final class SnapshotTests: XCTestCase {
    
    func testSnapshotInitialization() {
        let windows = [
            WindowInfo(
                appName: "Safari",
                windowTitle: "GitHub",
                x: 0,
                y: 0,
                width: 800,
                height: 600,
                isMinimized: false,
                isHidden: false,
                displayId: 1,
                pid: 1,
                bundleId: "com.apple.Safari",
                spaceId: nil,
                windowId: nil
            )
        ]
        
        let displays = [
            DisplayInfo(
                displayId: 1,
                name: "Main",
                width: 1920,
                height: 1080,
                x: 0,
                y: 0,
                isMain: true
            )
        ]
        
        let snapshot = Snapshot(
            name: "Work Setup",
            description: "My coding layout",
            windows: windows,
            displays: displays
        )
        
        XCTAssertEqual(snapshot.name, "Work Setup")
        XCTAssertEqual(snapshot.windowCount, 1)
        XCTAssertEqual(snapshot.displayCount, 1)
        XCTAssertEqual(snapshot.uniqueAppNames, ["Safari"])
    }
    
    func testSnapshotRemoveApp() {
        let windows = [
            WindowInfo(
                appName: "Safari",
                windowTitle: "GitHub",
                x: 0,
                y: 0,
                width: 800,
                height: 600,
                isMinimized: false,
                isHidden: false,
                displayId: 1,
                pid: 1,
                bundleId: nil,
                spaceId: nil,
                windowId: nil
            ),
            WindowInfo(
                appName: "Finder",
                windowTitle: "Documents",
                x: 800,
                y: 0,
                width: 400,
                height: 600,
                isMinimized: false,
                isHidden: false,
                displayId: 1,
                pid: 2,
                bundleId: nil,
                spaceId: nil,
                windowId: nil
            )
        ]
        
        let snapshot = Snapshot(
            name: "Test",
            windows: windows,
            displays: []
        )
        
        let filtered = snapshot.removing(appName: "Finder")
        XCTAssertEqual(filtered.windowCount, 1)
        XCTAssertEqual(filtered.windows.first?.appName, "Safari")
    }
}

// MARK: - RestoreReportTests

final class RestoreReportTests: XCTestCase {
    
    func testRestoreReportSuccess() {
        let report = RestoreReport(
            snapshotName: "Test",
            snapshotId: UUID(),
            startedAt: Date(),
            finishedAt: Date(),
            total: 5,
            restoredCount: 5,
            failedCount: 0,
            items: []
        )
        
        XCTAssertTrue(report.success)
        XCTAssertEqual(report.successRate, 100.0)
    }
    
    func testRestoreReportFailure() {
        let report = RestoreReport(
            snapshotName: "Test",
            snapshotId: UUID(),
            startedAt: Date(),
            finishedAt: Date(),
            total: 5,
            restoredCount: 3,
            failedCount: 2,
            items: []
        )
        
        XCTAssertFalse(report.success)
        XCTAssertEqual(report.successRate, 60.0, accuracy: 0.1)
    }
    
    func testRestoreItemStatus() {
        let restored = RestoreItem(
            appName: "Safari",
            windowTitle: "GitHub",
            restored: true,
            launched: false
        )
        XCTAssertEqual(restored.status, .restored)
        
        let failed = RestoreItem(
            appName: "Finder",
            windowTitle: "Docs",
            restored: false,
            launched: false,
            reason: "launch_failed"
        )
        if case .failed(let reason) = failed.status {
            XCTAssertEqual(reason, "launch_failed")
        } else {
            XCTFail("Expected failed status")
        }
    }
}

// MARK: - AppSettingsTests

final class AppSettingsTests: XCTestCase {
    
    func testDefaultSettings() {
        let settings = AppSettings()
        
        XCTAssertFalse(settings.startMinimized)
        XCTAssertFalse(settings.autoStart)
        XCTAssertEqual(settings.snapshots.autoSaveInterval, 300)
        XCTAssertEqual(settings.snapshots.maxSnapshots, 50)
    }
    
    func testHotkeyConfiguration() {
        var hotkeys = HotkeyConfiguration()
        XCTAssertEqual(hotkeys.saveSnapshot, "⌃⇧S")
        
        hotkeys.saveSnapshot = "⌘S"
        XCTAssertEqual(hotkeys.saveSnapshot, "⌘S")
    }
}
