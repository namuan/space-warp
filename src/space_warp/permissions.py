"""
Permissions helper for macOS accessibility and screen recording permissions
"""

import subprocess
import platform


class PermissionsHelper:
    """Helper for checking and requesting macOS permissions"""

    @staticmethod
    def check_accessibility_permissions() -> bool:
        """Check if the app has accessibility permissions"""
        try:
            # Test if we can access window information
            import Quartz

            window_list = Quartz.CGWindowListCopyWindowInfo(
                Quartz.kCGWindowListOptionOnScreenOnly, Quartz.kCGNullWindowID
            )
            return window_list is not None
        except Exception:
            return False

    @staticmethod
    def check_screen_recording_permissions() -> bool:
        """Check if the app has screen recording permissions"""
        try:
            import Quartz

            # Try to get display info which requires screen recording permission
            main_display = Quartz.CGMainDisplayID()
            if main_display == 0:
                return False

            # Try to get display bounds
            bounds = Quartz.CGDisplayBounds(main_display)
            return bounds is not None
        except Exception:
            return False

    @staticmethod
    def get_missing_permissions() -> list[str]:
        """Get list of missing permissions"""
        missing = []

        if not PermissionsHelper.check_accessibility_permissions():
            missing.append("Accessibility")

        if not PermissionsHelper.check_screen_recording_permissions():
            missing.append("Screen Recording")

        return missing

    @staticmethod
    def request_permissions_instructions() -> str:
        """Get instructions for granting permissions"""
        instructions = """
To use SpaceWarp, you need to grant the following permissions:

1. **Accessibility Permission** (required for window management):
   - Open System Preferences → Security & Privacy → Privacy
   - Select "Accessibility" from the left panel
   - Click the lock icon and enter your password
   - Add this application to the list
   - Check the checkbox next to the application

2. **Screen Recording Permission** (required for display info):
   - In the same Privacy panel, select "Screen Recording"
   - Add this application to the list
   - Check the checkbox next to the application

3. **Restart the application** after granting permissions

Note: You may see a security prompt when the app tries to access these features for the first time.
"""
        return instructions.strip()

    @staticmethod
    def open_system_preferences():
        """Open System Preferences to the Privacy section"""
        try:
            subprocess.run(
                [
                    "open",
                    "/System/Library/PreferencePanes/Security.prefPane",
                    "--args",
                    "Privacy_Accessibility",
                ]
            )
        except Exception as e:
            print(f"Could not open System Preferences: {e}")

    @staticmethod
    def is_macos() -> bool:
        """Check if running on macOS"""
        return platform.system() == "Darwin"

    @staticmethod
    def get_macos_version() -> tuple[int, int]:
        """Get macOS version as (major, minor) tuple"""
        try:
            version = platform.mac_ver()[0]
            if version:
                parts = version.split(".")
                major = int(parts[0]) if len(parts) > 0 else 10
                minor = int(parts[1]) if len(parts) > 1 else 0
                return (major, minor)
        except Exception:
            pass
        return (10, 0)
