"""
Window management system for capturing and restoring app layouts
"""

import time
from typing import Any
from dataclasses import dataclass
from PyQt6.QtCore import QObject, pyqtSignal

import Quartz
from AppKit import NSWorkspace


@dataclass
class WindowInfo:
    """Information about a window"""

    app_name: str
    window_title: str
    x: int
    y: int
    width: int
    height: int
    is_minimized: bool
    is_hidden: bool
    display_id: int
    pid: int


@dataclass
class DisplayInfo:
    """Information about a display"""

    display_id: int
    name: str
    width: int
    height: int
    x: int
    y: int
    is_main: bool


class WindowManager(QObject):
    """Manages window capture and restoration"""

    window_captured = pyqtSignal(WindowInfo)
    window_restored = pyqtSignal(str, str)  # app_name, window_title

    def __init__(self):
        super().__init__()
        self.workspace = NSWorkspace.sharedWorkspace()
        self._permissions_granted = self._check_permissions()

    def _check_permissions(self) -> bool:
        """Check if the app has necessary permissions"""
        try:
            # Test basic Quartz functionality
            main_display = Quartz.CGMainDisplayID()
            return main_display != 0
        except Exception as e:
            print(f"Permission check failed: {e}")
            return False

    def _get_main_display_fallback(self) -> list[DisplayInfo]:
        """Fallback display info when Quartz APIs fail"""
        try:
            # Try to get main display info
            main_display_id = Quartz.CGMainDisplayID()
            if main_display_id != 0:
                bounds = Quartz.CGDisplayBounds(main_display_id)
                return [
                    DisplayInfo(
                        display_id=main_display_id,
                        name="Main Display",
                        width=int(bounds.size.width),
                        height=int(bounds.size.height),
                        x=int(bounds.origin.x),
                        y=int(bounds.origin.y),
                        is_main=True,
                    )
                ]
        except Exception as e:
            print(f"Main display fallback failed: {e}")

        # Ultimate fallback - assume standard resolution
        return [
            DisplayInfo(
                display_id=1,
                name="Display",
                width=1920,
                height=1080,
                x=0,
                y=0,
                is_main=True,
            )
        ]

    def get_displays(self) -> list[DisplayInfo]:
        """Get information about all connected displays"""
        displays = []
        try:
            max_displays = 32
            display_count = Quartz.CGDisplayCount()
            online_displays = (Quartz.CGDirectDisplayID * max_displays)()

            result = Quartz.CGGetOnlineDisplayList(
                max_displays, online_displays, display_count
            )
            if result != 0:  # kCGErrorSuccess
                print(f"Warning: CGGetOnlineDisplayList returned error: {result}")
                # Return main display as fallback
                return self._get_main_display_fallback()

            for i in range(display_count.value):
                display_id = online_displays[i]
                bounds = Quartz.CGDisplayBounds(display_id)

                display_info = DisplayInfo(
                    display_id=display_id,
                    name=f"Display {display_id}",
                    width=int(bounds.size.width),
                    height=int(bounds.size.height),
                    x=int(bounds.origin.x),
                    y=int(bounds.origin.y),
                    is_main=(display_id == Quartz.CGMainDisplayID()),
                )
                displays.append(display_info)

        except Exception as e:
            print(f"Error getting displays: {e}")
            # Return main display as fallback
            return self._get_main_display_fallback()

        return displays if displays else self._get_main_display_fallback()

    def get_running_apps(self) -> list[dict[str, Any]]:
        """Get list of running applications"""
        apps = []
        running_apps = self.workspace.runningApplications()

        for app in running_apps:
            if app.activationPolicy() == 0:  # Regular apps only
                apps.append(
                    {
                        "name": app.localizedName(),
                        "bundle_id": app.bundleIdentifier(),
                        "pid": app.processIdentifier(),
                        "is_hidden": app.isHidden(),
                        "is_active": self.workspace.frontmostApplication() == app,
                    }
                )

        return apps

    def get_windows(self, app_name: str | None = None) -> list[WindowInfo]:
        """Get information about all windows or windows from specific app"""
        windows = []

        if not self._permissions_granted:
            print("Warning: Insufficient permissions to access window information")
            return windows

        try:
            # Get window list from Quartz Window Services
            window_list = Quartz.CGWindowListCopyWindowInfo(
                Quartz.kCGWindowListOptionOnScreenOnly
                | Quartz.kCGWindowListExcludeDesktopElements,
                Quartz.kCGNullWindowID,
            )

            if window_list:
                for window in window_list:
                    try:
                        # Skip system windows
                        window_layer = window.get(Quartz.kCGWindowLayer, 0)
                        if window_layer != 0:
                            continue

                        # Get window properties
                        owner_name = window.get(Quartz.kCGWindowOwnerName, "")
                        window_name = window.get(Quartz.kCGWindowName, "")
                        pid = window.get(Quartz.kCGWindowOwnerPID, 0)

                        # Skip empty or system windows
                        if not owner_name or owner_name in ["Window Server", "Dock"]:
                            continue

                        # Filter by app name if specified
                        if app_name and owner_name != app_name:
                            continue

                        # Get window bounds
                        bounds = window.get(Quartz.kCGWindowBounds, {})
                        if not bounds:
                            continue

                        x = bounds.get("X", 0)
                        y = bounds.get("Y", 0)
                        width = bounds.get("Width", 0)
                        height = bounds.get("Height", 0)

                        # Skip invalid windows
                        if width <= 0 or height <= 0:
                            continue

                        # Determine which display this window is on
                        display_id = self._get_display_for_window(x, y)

                        # Check if window is minimized (this is approximate)
                        is_minimized = self._is_window_minimized(pid, window_name)

                        window_info = WindowInfo(
                            app_name=owner_name,
                            window_title=window_name,
                            x=x,
                            y=y,
                            width=width,
                            height=height,
                            is_minimized=is_minimized,
                            is_hidden=False,  # Will be determined by app state
                            display_id=display_id,
                            pid=pid,
                        )

                        windows.append(window_info)
                        self.window_captured.emit(window_info)

                    except Exception as e:
                        print(f"Error processing window: {e}")
                        continue

        except Exception as e:
            print(f"Error getting window list: {e}")
            return windows

        return windows

    def _get_display_for_window(self, x: int, y: int) -> int:
        """Determine which display contains the window"""
        displays = self.get_displays()

        for display in displays:
            if (
                display.x <= x < display.x + display.width
                and display.y <= y < display.y + display.height
            ):
                return display.display_id

        # Default to main display if not found
        return Quartz.CGMainDisplayID()

    def _is_window_minimized(self, pid: int, window_title: str) -> bool:
        """Check if a window is minimized (approximate method)"""
        # This is a simplified check - in reality, this is complex on macOS
        # For now, we'll check if the app is hidden
        apps = self.get_running_apps()
        for app in apps:
            if app["pid"] == pid:
                return app["is_hidden"]
        return False

    def restore_window(self, window_info: WindowInfo) -> bool:
        """Restore a window to its captured state"""
        try:
            # First, try to bring the app to front
            self._activate_app(window_info.pid)

            # Wait a moment for the app to become active
            time.sleep(0.1)

            # Move and resize the window
            self._move_window(
                window_info.pid,
                window_info.x,
                window_info.y,
                window_info.width,
                window_info.height,
            )

            # Restore minimized state if needed
            if window_info.is_minimized:
                self._minimize_window(window_info.pid, False)

            self.window_restored.emit(window_info.app_name, window_info.window_title)
            return True

        except Exception as e:
            print(f"Error restoring window {window_info.app_name}: {e}")
            return False

    def _activate_app(self, pid: int) -> None:
        """Activate (bring to front) an application by PID"""
        apps = self.workspace.runningApplications()
        for app in apps:
            if app.processIdentifier() == pid:
                app.activateWithOptions_(0)  # NSApplicationActivateIgnoringOtherApps
                break

    def _move_window(self, pid: int, x: int, y: int, width: int, height: int) -> None:
        """Move and resize a window"""
        # This is a simplified implementation
        # In a real implementation, you would need to find the specific window
        # and use AppleScript or Accessibility APIs to move it

        # For now, we'll use a basic approach
        try:
            # Create AppleScript to move the window
            script = f"""
            tell application "System Events"
                tell (first application process whose unix id is {pid})
                    try
                        set position of window 1 to {{{x}, {y}}}
                        set size of window 1 to {{{width}, {height}}}
                    end try
                end tell
            end tell
            """

            # Execute AppleScript (this would need proper implementation)
            # os.system(f"osascript -e '{script}'")
            print(f"(this would need proper implementation) Executing script {script}")

        except Exception as e:
            print(f"Error moving window: {e}")

    def _minimize_window(self, pid: int, minimize: bool) -> None:
        """Minimize or restore a window"""
        try:
            apps = self.workspace.runningApplications()
            for app in apps:
                if app.processIdentifier() == pid:
                    if minimize:
                        app.hide()
                    else:
                        app.unhide()
                    break
        except Exception as e:
            print(f"Error minimizing/restoring window: {e}")

    def launch_app(self, bundle_id: str) -> bool:
        """Launch an application by bundle ID"""
        try:
            app_url = self.workspace.URLForApplicationWithBundleIdentifier_(bundle_id)
            if app_url:
                return self.workspace.launchApplicationAtURL_options_configuration_(
                    app_url, 0, None
                )[0]
            return False
        except Exception as e:
            print(f"Error launching app {bundle_id}: {e}")
            return False

    def quit_app(self, bundle_id: str) -> bool:
        """Quit an application by bundle ID"""
        try:
            apps = self.workspace.runningApplications()
            for app in apps:
                if app.bundleIdentifier() == bundle_id:
                    app.terminate()
                    return True
            return False
        except Exception as e:
            print(f"Error quitting app {bundle_id}: {e}")
            return False
