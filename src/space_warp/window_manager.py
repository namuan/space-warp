"""
Window management system for capturing and restoring app layouts
"""

import time
from typing import Any
import subprocess
from dataclasses import dataclass
from PyQt6.QtCore import QObject, pyqtSignal
import ctypes
from PyQt6.QtWidgets import QApplication

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
    bundle_id: str | None = None
    space_id: int | None = None
    window_id: int | None = None


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
    window_restore_started = pyqtSignal(str, str)
    window_restore_failed = pyqtSignal(str, str, str)
    window_launch_attempt = pyqtSignal(str, str)
    window_launch_result = pyqtSignal(str, bool, str)

    def __init__(self):
        super().__init__()
        self.workspace = NSWorkspace.sharedWorkspace()
        self._permissions_granted = self._check_permissions()
        self._skylight = None
        self._cf = None
        self._init_skylight()

    # ------------------------------
    # App visibility helpers
    # ------------------------------
    def _hide_app_by_ref(self, app_ref) -> bool:
        """Hide an NSRunningApplication reference. Returns True if a request was made."""
        try:
            # 0 = regular app; utility/background apps shouldn't be toggled
            if app_ref and app_ref.activationPolicy() == 0 and not app_ref.isHidden():
                app_ref.hide()
                return True
        except Exception as e:
            print(f"Error hiding app: {e}")
        return False

    def _init_skylight(self) -> None:
        try:
            self._skylight = ctypes.CDLL("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight")
            self._cf = ctypes.CDLL("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
        except Exception:
            self._skylight = None
            self._cf = None

    def _window_to_space_map(self) -> dict[int, int]:
        if not self._skylight or not self._cf:
            return {}
        try:
            conn = ctypes.c_uint32.in_dll(self._skylight, "SLSMainConnectionID")
        except Exception:
            try:
                get_conn = getattr(self._skylight, "SLSMainConnectionID")
                get_conn.restype = ctypes.c_uint32
                conn = ctypes.c_uint32(get_conn())
            except Exception:
                return {}
        try:
            copy_spaces = getattr(self._skylight, "SLSCopyManagedDisplaySpaces")
            copy_spaces.restype = ctypes.c_void_p
            spaces_ref = copy_spaces(conn)
            if not spaces_ref:
                return {}
        except Exception:
            return {}
        try:
            CFArrayGetCount = self._cf.CFArrayGetCount
            CFArrayGetCount.restype = ctypes.c_long
            CFArrayGetValueAtIndex = self._cf.CFArrayGetValueAtIndex
            CFArrayGetValueAtIndex.restype = ctypes.c_void_p
            CFDictionaryGetValue = self._cf.CFDictionaryGetValue
            CFDictionaryGetValue.restype = ctypes.c_void_p
            CFStringCreateWithCString = self._cf.CFStringCreateWithCString
            CFStringCreateWithCString.restype = ctypes.c_void_p
            CFNumberGetValue = self._cf.CFNumberGetValue
            CFNumberGetValue.restype = ctypes.c_bool
            kCFStringEncodingUTF8 = 0x08000100
            result: dict[int, int] = {}
            count = CFArrayGetCount(spaces_ref)
            for i in range(count):
                display_dict = CFArrayGetValueAtIndex(spaces_ref, i)
                key_spaces = CFStringCreateWithCString(None, b"Spaces", kCFStringEncodingUTF8)
                spaces_arr = CFDictionaryGetValue(display_dict, key_spaces)
                if not spaces_arr:
                    continue
                scount = CFArrayGetCount(spaces_arr)
                for j in range(scount):
                    space_dict = CFArrayGetValueAtIndex(spaces_arr, j)
                    key_id64 = CFStringCreateWithCString(None, b"id64", kCFStringEncodingUTF8)
                    key_windows = CFStringCreateWithCString(None, b"Windows", kCFStringEncodingUTF8)
                    id64_ref = CFDictionaryGetValue(space_dict, key_id64)
                    windows_arr = CFDictionaryGetValue(space_dict, key_windows)
                    if not id64_ref or not windows_arr:
                        continue
                    space_id = ctypes.c_longlong()
                    ok = CFNumberGetValue(id64_ref, 9, ctypes.byref(space_id))
                    if not ok:
                        continue
                    wcount = CFArrayGetCount(windows_arr)
                    for k in range(wcount):
                        wref = CFArrayGetValueAtIndex(windows_arr, k)
                        wid = ctypes.c_int()
                        ok2 = CFNumberGetValue(wref, 9, ctypes.byref(wid))
                        if ok2:
                            result[int(wid.value)] = int(space_id.value)
            return result
        except Exception:
            return {}

    def _unhide_app_by_ref(self, app_ref) -> bool:
        """Unhide an NSRunningApplication reference. Returns True if a request was made."""
        try:
            if app_ref and app_ref.activationPolicy() == 0 and app_ref.isHidden():
                app_ref.unhide()
                return True
        except Exception as e:
            print(f"Error unhiding app: {e}")
        return False

    def _hide_non_profile_apps(self, snapshot) -> None:
        """Hide all currently running regular apps that are not present in the target snapshot.

        The goal is to keep non‑profile apps safe (not quit) while keeping the
        workspace focused. Apps included in the snapshot will remain visible or
        get unhidden during restore.
        """
        try:
            running = self.workspace.runningApplications()
            keep_names = {w.app_name for w in snapshot.windows if getattr(w, 'app_name', None)}
            keep_bundles = {w.bundle_id for w in snapshot.windows if getattr(w, 'bundle_id', None)}

            for app in running:
                try:
                    # Skip non-regular apps
                    if app.activationPolicy() != 0:
                        continue

                    name = None
                    bid = None
                    try:
                        name = app.localizedName()
                    except Exception:
                        pass
                    try:
                        bid = app.bundleIdentifier()
                    except Exception:
                        pass

                    # If app is part of the profile (by bundle id or name), do not hide
                    if (bid and bid in keep_bundles) or (name and name in keep_names):
                        continue

                    self._hide_app_by_ref(app)
                except Exception:
                    # Continue on best-effort basis
                    continue
        except Exception as e:
            print(f"Error hiding non-profile apps: {e}")

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
        app = QApplication.instance()
        if app:
            screens = app.screens()
            if screens:
                displays: list[DisplayInfo] = []
                primary = app.primaryScreen()
                for idx, screen in enumerate(screens):
                    geo = screen.geometry()
                    displays.append(
                        DisplayInfo(
                            display_id=idx + 1,
                            name=screen.name() or f"Display {idx+1}",
                            width=geo.width(),
                            height=geo.height(),
                            x=geo.x(),
                            y=geo.y(),
                            is_main=(screen == primary),
                        )
                    )
                return displays

        try:
            max_displays = 32
            count = Quartz.CGDisplayCount
            online_displays = (Quartz.CGDirectDisplayID * max_displays)()
            result = Quartz.CGGetOnlineDisplayList(max_displays, online_displays, count)
            if result != 0:
                return self._get_main_display_fallback()
            displays: list[DisplayInfo] = []
            for i in range(max_displays):
                did = online_displays[i]
                if not did:
                    break
                bounds = Quartz.CGDisplayBounds(did)
                displays.append(
                    DisplayInfo(
                        display_id=did,
                        name=f"Display {did}",
                        width=int(bounds.size.width),
                        height=int(bounds.size.height),
                        x=int(bounds.origin.x),
                        y=int(bounds.origin.y),
                        is_main=(did == Quartz.CGMainDisplayID()),
                    )
                )
            return displays if displays else self._get_main_display_fallback()
        except Exception:
            return self._get_main_display_fallback()

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
            apps = self.get_running_apps()
            bundle_by_pid = {a["pid"]: a.get("bundle_id") for a in apps}
            window_list = Quartz.CGWindowListCopyWindowInfo(
                Quartz.kCGWindowListOptionOnScreenOnly
                | Quartz.kCGWindowListExcludeDesktopElements,
                Quartz.kCGNullWindowID,
            )

            if window_list:
                mapping = self._window_to_space_map()
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
                        wid = window.get(Quartz.kCGWindowNumber, 0)

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

                        display_id = self._get_display_for_window(x, y, width, height)

                        # Check if window is minimized (this is approximate)
                        is_minimized = self._is_window_minimized(pid, window_name)
                        bundle_id = bundle_by_pid.get(pid)

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
                            bundle_id=bundle_id,
                            space_id=mapping.get(int(wid)) if mapping else None,
                            window_id=int(wid) if wid else None,
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

    def get_windows_all_spaces(self, app_name: str | None = None) -> list[WindowInfo]:
        windows = []
        if not self._permissions_granted:
            return windows
        try:
            apps = self.get_running_apps()
            bundle_by_pid = {a["pid"]: a.get("bundle_id") for a in apps}
            window_list = Quartz.CGWindowListCopyWindowInfo(
                Quartz.kCGWindowListOptionAll | Quartz.kCGWindowListExcludeDesktopElements,
                Quartz.kCGNullWindowID,
            )
            mapping = self._window_to_space_map()
            if window_list:
                for window in window_list:
                    try:
                        window_layer = window.get(Quartz.kCGWindowLayer, 0)
                        if window_layer != 0:
                            continue
                        owner_name = window.get(Quartz.kCGWindowOwnerName, "")
                        window_name = window.get(Quartz.kCGWindowName, "")
                        pid = window.get(Quartz.kCGWindowOwnerPID, 0)
                        wid = window.get(Quartz.kCGWindowNumber, 0)
                        if not owner_name or owner_name in ["Window Server", "Dock"]:
                            continue
                        if app_name and owner_name != app_name:
                            continue
                        bounds = window.get(Quartz.kCGWindowBounds, {})
                        if not bounds:
                            continue
                        x = bounds.get("X", 0)
                        y = bounds.get("Y", 0)
                        width = bounds.get("Width", 0)
                        height = bounds.get("Height", 0)
                        if width <= 0 or height <= 0:
                            continue
                        display_id = self._get_display_for_window(x, y, width, height)
                        is_minimized = self._is_window_minimized(pid, window_name)
                        bundle_id = bundle_by_pid.get(pid)
                        windows.append(
                            WindowInfo(
                                app_name=owner_name,
                                window_title=window_name,
                                x=x,
                                y=y,
                                width=width,
                                height=height,
                                is_minimized=is_minimized,
                                is_hidden=False,
                                display_id=display_id,
                                pid=pid,
                                bundle_id=bundle_id,
                                space_id=mapping.get(int(wid)) if mapping else None,
                                window_id=int(wid) if wid else None,
                            )
                        )
                    except Exception:
                        continue
        except Exception:
            return windows
        return windows

    def _get_display_for_window(self, x: int, y: int, width: int, height: int) -> int:
        displays = self.get_displays()

        win_min_x = x
        win_max_x = x + width
        win_min_y = y
        win_max_y = y + height

        best_display_id = None
        best_area = -1

        for display in displays:
            disp_min_x = display.x
            disp_max_x = display.x + display.width
            disp_min_y = display.y
            disp_max_y = display.y + display.height

            inter_w = min(win_max_x, disp_max_x) - max(win_min_x, disp_min_x)
            inter_h = min(win_max_y, disp_max_y) - max(win_min_y, disp_min_y)

            if inter_w > 0 and inter_h > 0:
                area = inter_w * inter_h
                if area > best_area:
                    best_area = area
                    best_display_id = display.display_id

        if best_display_id is not None:
            return best_display_id

        cx = x + (width // 2)
        cy = y + (height // 2)
        for display in displays:
            if (
                display.x <= cx < display.x + display.width
                and display.y <= cy < display.y + display.height
            ):
                return display.display_id

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
            self.window_restore_started.emit(window_info.app_name, window_info.window_title)
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
                window_info.window_title or None,
            )

            # Restore minimized state if needed
            if window_info.is_minimized:
                self._minimize_window(window_info.pid, False)

            self.window_restored.emit(window_info.app_name, window_info.window_title)
            return True

        except Exception as e:
            print(f"Error restoring window {window_info.app_name}: {e}")
            try:
                reason = str(e) if str(e) else "restore_error"
                self.window_restore_failed.emit(window_info.app_name, window_info.window_title, reason)
            except Exception:
                pass
            return False

    def _activate_app(self, pid: int) -> None:
        """Activate (bring to front) an application by PID"""
        apps = self.workspace.runningApplications()
        for app in apps:
            if app.processIdentifier() == pid:
                app.activateWithOptions_(0)  # NSApplicationActivateIgnoringOtherApps
                break

    def _move_window(self, pid: int, x: int, y: int, width: int, height: int, title: str | None = None) -> None:
        """Move and resize a window"""
        # This is a simplified implementation
        # In a real implementation, you would need to find the specific window
        # and use AppleScript or Accessibility APIs to move it

        # For now, we'll use a basic approach
        try:
            target = (
                f"set position of (first window whose name is \"{title}\") to {{{x}, {y}}}\n"
                f"set size of (first window whose name is \"{title}\") to {{{width}, {height}}}"
                if title
                else f"set position of window 1 to {{{x}, {y}}}\nset size of window 1 to {{{width}, {height}}}"
            )
            script = (
                "tell application \"System Events\"\n"
                f"tell (first application process whose unix id is {pid})\n"
                f"try\n{target}\nend try\nend tell\nend tell"
            )
            subprocess.run(["osascript", "-e", script], check=False)
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

    def launch_app_by_name(self, app_name: str) -> tuple[bool, str]:
        try:
            self.window_launch_attempt.emit(app_name, f"NSWorkspace.launchApplication_('{app_name}')")
            try:
                ok = bool(self.workspace.launchApplication_(app_name))
            except Exception:
                ok = False
            if ok:
                self.window_launch_result.emit(app_name, True, "nsworkspace")
                return True, f"NSWorkspace.launchApplication_('{app_name}')"
            self.window_launch_attempt.emit(app_name, f"open -a {app_name}")
            try:
                subprocess.run(["open", "-a", app_name], check=False)
                self.window_launch_result.emit(app_name, True, "open -a")
                return True, f"open -a {app_name}"
            except Exception:
                pass
            self.window_launch_result.emit(app_name, False, "launch_failed")
            return False, "launch_failed"
        except Exception as e:
            print(f"Error launching app {app_name}: {e}")
            try:
                self.window_launch_result.emit(app_name, False, str(e) if str(e) else "error")
            except Exception:
                pass
            return False, "error"

    def launch_app_prefer_info(self, app_name: str, bundle_id: str | None) -> tuple[bool, str]:
        try:
            if bundle_id:
                self.window_launch_attempt.emit(app_name, f"bundle '{bundle_id}' via NSWorkspace")
                ok = self.launch_app(bundle_id)
                if ok:
                    self.window_launch_result.emit(app_name, True, "bundle_id")
                    return True, f"bundle '{bundle_id}' via NSWorkspace"
                self.window_launch_attempt.emit(app_name, f"open -b {bundle_id}")
                try:
                    subprocess.run(["open", "-b", bundle_id], check=False)
                    self.window_launch_result.emit(app_name, True, "open -b")
                    return True, f"open -b {bundle_id}"
                except Exception:
                    pass
            # Fallback to name-based
            return self.launch_app_by_name(app_name)
        except Exception as e:
            print(f"Error launching app {app_name} (prefer bundle): {e}")
            try:
                self.window_launch_result.emit(app_name, False, str(e) if str(e) else "error")
            except Exception:
                pass
            return False, "error"

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

    def restore_layout(self, snapshot) -> bool:
        try:
            # First, hide all other running apps to keep the desktop focused on this profile
            self._hide_non_profile_apps(snapshot)

            current = self.get_windows()
            ok = True
            for w in snapshot.windows:
                self.window_restore_started.emit(w.app_name, w.window_title)
                candidates = [cw for cw in current if cw.app_name == w.app_name]
                chosen = None
                if candidates:
                    exact = [cw for cw in candidates if cw.window_title == w.window_title]
                    chosen = exact[0] if exact else candidates[0]
                    # Ensure app is visible
                    try:
                        apps = self.workspace.runningApplications()
                        for app in apps:
                            if app.processIdentifier() == chosen.pid:
                                self._unhide_app_by_ref(app)
                                break
                    except Exception:
                        pass
                    self._activate_app(chosen.pid)
                    time.sleep(0.1)
                    need_move = (
                        abs(chosen.x - w.x) > 2
                        or abs(chosen.y - w.y) > 2
                        or abs(chosen.width - w.width) > 2
                        or abs(chosen.height - w.height) > 2
                    )
                    if need_move:
                        self._move_window(
                            chosen.pid,
                            w.x,
                            w.y,
                            w.width,
                            w.height,
                            w.window_title or None,
                        )
                    if w.is_minimized:
                        self._minimize_window(chosen.pid, False)
                    self.window_restored.emit(w.app_name, w.window_title)
                else:
                    launched, launch_cmd = self.launch_app_prefer_info(w.app_name, w.bundle_id)
                    if not launched:
                        ok = False
                        try:
                            self.window_restore_failed.emit(w.app_name, w.window_title, "launch_failed")
                        except Exception:
                            pass
                        continue
                    chosen = None
                    # Wait for window to appear (progressive backoff up to ~30s)
                    for i in range(200):
                        time.sleep(0.15 if i < 100 else 0.3)
                        current = self.get_windows(w.app_name)
                        if current:
                            chosen = current[0]
                            break
                    if not chosen:
                        ok = False
                        try:
                            self.window_restore_failed.emit(w.app_name, w.window_title, "window_timeout")
                        except Exception:
                            pass
                        continue
                    # Unhide and activate newly launched app
                    try:
                        apps = self.workspace.runningApplications()
                        for app in apps:
                            if app.localizedName() == w.app_name or (w.bundle_id and app.bundleIdentifier() == w.bundle_id):
                                self._unhide_app_by_ref(app)
                                break
                    except Exception:
                        pass
                    self._activate_app(chosen.pid)
                    time.sleep(0.1)
                    self._move_window(
                        chosen.pid,
                        w.x,
                        w.y,
                        w.width,
                        w.height,
                        w.window_title or None,
                    )
                    if w.is_minimized:
                        self._minimize_window(chosen.pid, False)
                    self.window_restored.emit(w.app_name, w.window_title)
            return ok
        except Exception as e:
            print(f"Error restoring layout: {e}")
            return False

    def restore_layout_with_report(self, snapshot) -> tuple[bool, list[dict[str, Any]]]:
        try:
            # Hide irrelevant apps first
            self._hide_non_profile_apps(snapshot)

            current = self.get_windows()
            ok = True
            items: list[dict[str, Any]] = []
            for w in snapshot.windows:
                self.window_restore_started.emit(w.app_name, w.window_title)
                entry = {
                    "app_name": w.app_name,
                    "window_title": w.window_title,
                    "restored": False,
                    "launched": False,
                    "reason": None,
                }
                candidates = [cw for cw in current if cw.app_name == w.app_name]
                chosen = None
                if candidates:
                    exact = [cw for cw in candidates if cw.window_title == w.window_title]
                    chosen = exact[0] if exact else candidates[0]
                    # Ensure visibility
                    try:
                        apps = self.workspace.runningApplications()
                        for app in apps:
                            if app.processIdentifier() == chosen.pid:
                                self._unhide_app_by_ref(app)
                                break
                    except Exception:
                        pass
                    self._activate_app(chosen.pid)
                    time.sleep(0.1)
                    need_move = (
                        abs(chosen.x - w.x) > 2
                        or abs(chosen.y - w.y) > 2
                        or abs(chosen.width - w.width) > 2
                        or abs(chosen.height - w.height) > 2
                    )
                    if need_move:
                        self._move_window(
                            chosen.pid,
                            w.x,
                            w.y,
                            w.width,
                            w.height,
                            w.window_title or None,
                        )
                    if w.is_minimized:
                        self._minimize_window(chosen.pid, False)
                    self.window_restored.emit(w.app_name, w.window_title)
                    entry["restored"] = True
                else:
                    launched, launch_cmd = self.launch_app_prefer_info(w.app_name, w.bundle_id)
                    entry["launched"] = bool(launched)
                    entry["launch_command"] = launch_cmd
                    if not launched:
                        ok = False
                        entry["reason"] = "launch_failed"
                        try:
                            self.window_restore_failed.emit(w.app_name, w.window_title, "launch_failed")
                        except Exception:
                            pass
                        items.append(entry)
                        continue
                    chosen = None
                    # Wait for window to appear (progressive backoff up to ~30s)
                    for i in range(200):
                        time.sleep(0.15 if i < 100 else 0.3)
                        current = self.get_windows(w.app_name)
                        if current:
                            chosen = current[0]
                            break
                    if not chosen:
                        ok = False
                        entry["reason"] = "window_timeout"
                        try:
                            self.window_restore_failed.emit(w.app_name, w.window_title, "window_timeout")
                        except Exception:
                            pass
                        items.append(entry)
                        continue
                    # Ensure visibility of launched app
                    try:
                        apps = self.workspace.runningApplications()
                        for app in apps:
                            if app.localizedName() == w.app_name or (w.bundle_id and app.bundleIdentifier() == w.bundle_id):
                                self._unhide_app_by_ref(app)
                                break
                    except Exception:
                        pass
                    self._activate_app(chosen.pid)
                    time.sleep(0.1)
                    self._move_window(
                        chosen.pid,
                        w.x,
                        w.y,
                        w.width,
                        w.height,
                        w.window_title or None,
                    )
                    if w.is_minimized:
                        self._minimize_window(chosen.pid, False)
                    self.window_restored.emit(w.app_name, w.window_title)
                    entry["restored"] = True
                items.append(entry)
            return ok, items
        except Exception as e:
            print(f"Error restoring layout: {e}")
            return False, []
