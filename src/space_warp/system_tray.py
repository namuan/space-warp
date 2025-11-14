"""
System tray icon for SpaceWarp
"""

import os
import sys
from PyQt6.QtWidgets import QSystemTrayIcon, QMenu, QApplication
from PyQt6.QtGui import QIcon, QAction

from .config import Config


class SystemTrayIcon(QSystemTrayIcon):
    """System tray icon for the application"""

    def __init__(self, main_window, config: Config, parent=None):
        super().__init__(parent)
        self.main_window = main_window
        self.config = config

        # Set icon (we'll create a simple icon)
        self.set_icon()

        # Create context menu
        self.create_context_menu()

        # Connect signals
        self.activated.connect(self.on_activated)

        # Show the tray icon
        self.show()

    def set_icon(self):
        path = self._resource_path("assets/space-warp-icon.png")
        self.setIcon(QIcon(path))
        self.setToolTip("SpaceWarp - Window Layout Manager")

    def _resource_path(self, relative):
        base = getattr(sys, "_MEIPASS", None)
        if base:
            p = os.path.join(base, relative)
            if os.path.exists(p):
                return p
        here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        p = os.path.join(here, relative)
        if os.path.exists(p):
            return p
        return relative

    def create_context_menu(self):
        """Create the context menu for the tray icon"""
        menu = QMenu()

        # Show main window
        show_action = QAction("Show Window Manager", self)
        show_action.triggered.connect(self.show_main_window)
        menu.addAction(show_action)

        menu.addSeparator()

        # Quick snapshot actions
        save_action = QAction("Save Current Layout...", self)
        save_action.triggered.connect(self.save_snapshot)
        menu.addAction(save_action)

        restore_menu = menu.addMenu("Restore Layout")
        self.populate_restore_menu(restore_menu)

        menu.addSeparator()

        # Settings
        settings_action = QAction("Settings...", self)
        settings_action.triggered.connect(self.show_settings)
        menu.addAction(settings_action)

        menu.addSeparator()

        # Exit
        exit_action = QAction("Exit", self)
        exit_action.triggered.connect(self.exit_application)
        menu.addAction(exit_action)

        self.setContextMenu(menu)

    def populate_restore_menu(self, menu):
        """Populate the restore menu with saved snapshots"""
        menu.clear()

        try:
            from .snapshot_manager import SnapshotManager

            snapshot_manager = SnapshotManager(self.config)
            snapshot_names = snapshot_manager.get_snapshot_names()

            if snapshot_names:
                for name in snapshot_names:
                    action = QAction(name, self)
                    action.triggered.connect(
                        lambda checked, n=name: self.restore_snapshot(n)
                    )
                    menu.addAction(action)
            else:
                no_snapshots_action = QAction("No snapshots saved", self)
                no_snapshots_action.setEnabled(False)
                menu.addAction(no_snapshots_action)

        except Exception:
            error_action = QAction("Error loading snapshots", self)
            error_action.setEnabled(False)
            menu.addAction(error_action)

    def on_activated(self, reason):
        """Handle tray icon activation"""
        if reason == QSystemTrayIcon.ActivationReason.Trigger:
            self.show_main_window()

    def show_main_window(self):
        """Show the main window"""
        self.main_window.show()
        self.main_window.raise_()
        self.main_window.activateWindow()

    def save_snapshot(self):
        """Save a new snapshot"""
        self.show_main_window()
        self.main_window.save_snapshot_dialog()

    def restore_snapshot(self, name):
        """Restore a snapshot by name"""
        try:
            from .snapshot_manager import SnapshotManager
            from .window_manager import WindowManager

            snapshot_manager = SnapshotManager(self.config)
            window_manager = WindowManager()
            report = snapshot_manager.restore_snapshot_with_report(name, window_manager)
            if report is None:
                self.showMessage(
                    "Restore Failed",
                    f"Failed to restore snapshot '{name}'",
                    QSystemTrayIcon.MessageIcon.Critical,
                    3000,
                )
                return
            if report.failed_count == 0:
                self.showMessage(
                    "Snapshot Restored",
                    f"Restored {report.restored_count}/{report.total} for '{name}'",
                    QSystemTrayIcon.MessageIcon.Information,
                    3000,
                )
            else:
                failed_apps = ", ".join(sorted({f["app_name"] for f in report.items if not f.get("restored")}))
                self.showMessage(
                    "Restore Completed With Failures",
                    f"Restored {report.restored_count}/{report.total}; failed: {failed_apps}",
                    QSystemTrayIcon.MessageIcon.Warning,
                    5000,
                )

        except Exception as e:
            self.showMessage(
                "Restore Error",
                f"Error restoring snapshot: {str(e)}",
                QSystemTrayIcon.MessageIcon.Critical,
                3000,
            )

    def show_settings(self):
        """Show settings dialog"""
        self.show_main_window()
        # This would open settings in the main window

    def exit_application(self):
        """Exit the application"""
        QApplication.quit()

    def refresh_menu(self):
        """Refresh the context menu"""
        self.create_context_menu()
