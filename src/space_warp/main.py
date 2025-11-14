"""
SpaceWarp - A revolutionary multi-display window and app layout manager for macOS
"""

import sys
from PyQt6.QtWidgets import QApplication

from .main_window import MainWindow
from .system_tray import SystemTrayIcon
from .window_manager import WindowManager
from .snapshot_manager import SnapshotManager
from .config import Config


def main():
    """Main application entry point"""
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)

    # Set application metadata
    app.setApplicationName("SpaceWarp")
    app.setApplicationVersion("0.1.0")
    app.setOrganizationName("SpaceWarp")

    # Initialize configuration
    config = Config()

    # Initialize core components
    window_manager = WindowManager()
    snapshot_manager = SnapshotManager(config)

    # Create main window (initially hidden)
    main_window = MainWindow(window_manager, snapshot_manager, config)

    # Create system tray icon
    tray_icon = SystemTrayIcon(main_window, config)
    tray_icon.show()

    # Apply any saved settings
    if config.get("start_minimized", True):
        main_window.hide()
    else:
        main_window.show()

    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
