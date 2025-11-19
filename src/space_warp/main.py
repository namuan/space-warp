"""
SpaceWarp - A revolutionary multi-display window and app layout manager for macOS
"""

import sys
from PyQt6.QtWidgets import QApplication
from PyQt6.QtGui import QPalette

from .main_window import MainWindow
from .window_manager import WindowManager
from .snapshot_manager import SnapshotManager
from .config import Config


def main():
    """Main application entry point"""
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(True)

    # Set application metadata
    app.setApplicationName("SpaceWarp")
    app.setApplicationVersion("0.1.0")
    app.setOrganizationName("SpaceWarp")

    # Apply Fusion style with light palette
    app.setStyle("Fusion")
    app.setPalette(app.style().standardPalette())

    # Initialize configuration
    config = Config()

    # Initialize core components
    window_manager = WindowManager()
    snapshot_manager = SnapshotManager(config)

    # Create main window (initially hidden)
    main_window = MainWindow(window_manager, snapshot_manager, config)


    main_window.show()

    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
