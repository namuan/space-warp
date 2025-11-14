"""
Main window for SpaceWarp
"""

from PyQt6.QtWidgets import (
    QMainWindow,
    QWidget,
    QVBoxLayout,
    QHBoxLayout,
    QPushButton,
    QListWidget,
    QListWidgetItem,
    QTextEdit,
    QLineEdit,
    QLabel,
    QGroupBox,
    QSplitter,
    QMessageBox,
    QStatusBar,
    QDialog,
    QDialogButtonBox,
)
from PyQt6.QtCore import Qt, QTimer
from PyQt6.QtGui import QAction, QKeySequence
from datetime import datetime

from .window_manager import WindowManager
from .snapshot_manager import SnapshotManager
from .config import Config
from .permissions import PermissionsHelper


class SnapshotDialog(QDialog):
    """Dialog for creating/editing snapshots"""

    def __init__(self, parent=None, snapshot_name="", description=""):
        super().__init__(parent)
        self.setWindowTitle("Save Snapshot")
        self.setModal(True)
        self.resize(400, 200)

        layout = QVBoxLayout(self)

        # Name input
        name_layout = QHBoxLayout()
        name_layout.addWidget(QLabel("Name:"))
        self.name_edit = QLineEdit(snapshot_name)
        self.name_edit.setPlaceholderText("Enter snapshot name...")
        name_layout.addWidget(self.name_edit)
        layout.addLayout(name_layout)

        # Description input
        layout.addWidget(QLabel("Description:"))
        self.description_edit = QTextEdit()
        self.description_edit.setPlainText(description)
        self.description_edit.setMaximumHeight(80)
        self.description_edit.setPlaceholderText("Enter snapshot description...")
        layout.addWidget(self.description_edit)

        # Buttons
        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel,
            Qt.Orientation.Horizontal,
            self,
        )
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

    def get_data(self):
        return (
            self.name_edit.text().strip(),
            self.description_edit.toPlainText().strip(),
        )


class MainWindow(QMainWindow):
    """Main application window"""

    def __init__(
        self,
        window_manager: WindowManager,
        snapshot_manager: SnapshotManager,
        config: Config,
    ):
        super().__init__()
        self.window_manager = window_manager
        self.snapshot_manager = snapshot_manager
        self.config = config
        self.permissions_helper = PermissionsHelper()

        self.setWindowTitle("SpaceWarp - Window Layout Manager")
        self.setGeometry(100, 100, 1200, 800)

        self.init_ui()
        self.setup_menu_bar()
        self.setup_status_bar()
        self.setup_shortcuts()

        # Check permissions on startup
        self.check_permissions()

        # Update timer
        self.update_timer = QTimer()
        self.update_timer.timeout.connect(self.update_window_list)
        self.update_timer.start(2000)  # Update every 2 seconds

        # Load initial data
        self.load_snapshots()
        self.update_window_list()

    def init_ui(self):
        """Initialize the user interface"""
        central_widget = QWidget()
        self.setCentralWidget(central_widget)

        # Main layout
        main_layout = QHBoxLayout(central_widget)

        # Create splitter for resizable panels
        splitter = QSplitter(Qt.Orientation.Horizontal)
        main_layout.addWidget(splitter)

        # Left panel - Current Windows
        left_panel = self.create_current_windows_panel()
        splitter.addWidget(left_panel)

        # Right panel - Snapshots
        right_panel = self.create_snapshots_panel()
        splitter.addWidget(right_panel)

        # Set splitter proportions
        splitter.setSizes([600, 600])

    def create_current_windows_panel(self):
        """Create the current windows panel"""
        group = QGroupBox("Current Windows")
        layout = QVBoxLayout(group)

        # Window list
        self.window_list = QListWidget()
        self.window_list.itemSelectionChanged.connect(self.on_window_selected)
        layout.addWidget(self.window_list)

        # Control buttons
        button_layout = QHBoxLayout()

        self.refresh_btn = QPushButton("Refresh")
        self.refresh_btn.clicked.connect(self.update_window_list)
        button_layout.addWidget(self.refresh_btn)

        self.capture_all_btn = QPushButton("Capture All")
        self.capture_all_btn.clicked.connect(self.capture_all_windows)
        button_layout.addWidget(self.capture_all_btn)

        layout.addLayout(button_layout)

        return group

    def create_snapshots_panel(self):
        """Create the snapshots panel"""
        group = QGroupBox("Saved Snapshots")
        layout = QVBoxLayout(group)

        # Snapshot list
        self.snapshot_list = QListWidget()
        self.snapshot_list.itemSelectionChanged.connect(self.on_snapshot_selected)
        self.snapshot_list.itemDoubleClicked.connect(self.restore_selected_snapshot)
        layout.addWidget(self.snapshot_list)

        # Snapshot info
        self.snapshot_info = QTextEdit()
        self.snapshot_info.setMaximumHeight(100)
        self.snapshot_info.setReadOnly(True)
        layout.addWidget(self.snapshot_info)

        # Control buttons
        button_layout = QHBoxLayout()

        self.save_snapshot_btn = QPushButton("Save Snapshot")
        self.save_snapshot_btn.clicked.connect(self.save_snapshot_dialog)
        button_layout.addWidget(self.save_snapshot_btn)

        self.restore_snapshot_btn = QPushButton("Restore")
        self.restore_snapshot_btn.clicked.connect(self.restore_selected_snapshot)
        button_layout.addWidget(self.restore_snapshot_btn)

        self.delete_snapshot_btn = QPushButton("Delete")
        self.delete_snapshot_btn.clicked.connect(self.delete_selected_snapshot)
        button_layout.addWidget(self.delete_snapshot_btn)

        layout.addLayout(button_layout)

        return group

    def setup_menu_bar(self):
        """Setup the menu bar"""
        menubar = self.menuBar()

        # File menu
        file_menu = menubar.addMenu("File")

        save_action = QAction("Save Snapshot...", self)
        save_action.setShortcut(QKeySequence.StandardKey.Save)
        save_action.triggered.connect(self.save_snapshot_dialog)
        file_menu.addAction(save_action)

        file_menu.addSeparator()

        exit_action = QAction("Exit", self)
        exit_action.setShortcut(QKeySequence.StandardKey.Quit)
        exit_action.triggered.connect(self.close)
        file_menu.addAction(exit_action)

        # View menu
        view_menu = menubar.addMenu("View")

        refresh_action = QAction("Refresh", self)
        refresh_action.setShortcut(QKeySequence.StandardKey.Refresh)
        refresh_action.triggered.connect(self.update_window_list)
        view_menu.addAction(refresh_action)

        # Tools menu
        tools_menu = menubar.addMenu("Tools")

        capture_action = QAction("Capture Current Layout", self)
        capture_action.triggered.connect(self.capture_all_windows)
        tools_menu.addAction(capture_action)

        # Help menu
        help_menu = menubar.addMenu("Help")

        permissions_action = QAction("Check Permissions...", self)
        permissions_action.triggered.connect(self.show_permissions_instructions)
        help_menu.addAction(permissions_action)

        help_menu.addSeparator()

        about_action = QAction("About", self)
        about_action.triggered.connect(self.show_about)
        help_menu.addAction(about_action)

    def setup_status_bar(self):
        """Setup the status bar"""
        self.status_bar = QStatusBar()
        self.setStatusBar(self.status_bar)
        self.status_bar.showMessage("Ready")

    def setup_shortcuts(self):
        """Setup keyboard shortcuts"""
        # These would be configurable in a real implementation
        shortcuts = [
            ("Ctrl+Shift+S", self.save_snapshot_dialog),
            ("Ctrl+Shift+R", self.restore_selected_snapshot),
            ("Ctrl+Shift+M", self.show_window_manager),
        ]

        for shortcut, callback in shortcuts:
            action = QAction(self)
            action.setShortcut(QKeySequence(shortcut))
            action.triggered.connect(callback)
            self.addAction(action)

    def update_window_list(self):
        """Update the current windows list"""
        self.window_list.clear()

        try:
            windows = self.window_manager.get_windows()
            displays = self.window_manager.get_displays()

            for window in windows:
                # Create display info string
                display_info = ""
                for display in displays:
                    if display.display_id == window.display_id:
                        display_info = f" - {display.name}"
                        break

                # Create window item
                status = ""
                if window.is_minimized:
                    status = " [Minimized]"
                elif window.is_hidden:
                    status = " [Hidden]"

                item_text = (
                    f"{window.app_name}: {window.window_title}{status}{display_info}"
                )
                item = QListWidgetItem(item_text)
                item.setData(Qt.ItemDataRole.UserRole, window)
                self.window_list.addItem(item)

            # Show permission status in status bar
            if not self.window_manager._permissions_granted:
                self.status_bar.showMessage(
                    "⚠️ Permissions required - check Help menu for instructions"
                )
            else:
                self.status_bar.showMessage(
                    f"Found {len(windows)} windows on {len(displays)} displays"
                )

        except Exception as e:
            self.status_bar.showMessage(f"Error updating window list: {e}")

    def load_snapshots(self):
        """Load saved snapshots"""
        self.snapshot_list.clear()

        try:
            snapshots = self.snapshot_manager.get_all_snapshots()
            for snapshot in snapshots:
                item = QListWidgetItem(snapshot.name)
                item.setData(Qt.ItemDataRole.UserRole, snapshot)
                self.snapshot_list.addItem(item)

            self.status_bar.showMessage(f"Loaded {len(snapshots)} snapshots")

        except Exception as e:
            self.status_bar.showMessage(f"Error loading snapshots: {e}")

    def on_window_selected(self):
        """Handle window selection"""
        pass  # Could show window details here

    def on_snapshot_selected(self):
        """Handle snapshot selection"""
        current_item = self.snapshot_list.currentItem()
        if current_item:
            snapshot = current_item.data(Qt.ItemDataRole.UserRole)
            if snapshot:
                info = f"Created: {snapshot.created_at.strftime('%Y-%m-%d %H:%M:%S')}\n"
                info += f"Windows: {len(snapshot.windows)}\n"
                info += f"Displays: {len(snapshot.displays)}\n"
                info += f"Description: {snapshot.description}"
                self.snapshot_info.setPlainText(info)

    def capture_all_windows(self):
        """Capture all current windows"""
        try:
            windows = self.window_manager.get_windows()
            displays = self.window_manager.get_displays()

            # Auto-generate name
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            name = f"Auto_{timestamp}"
            description = f"Auto-captured layout with {len(windows)} windows"

            # Save snapshot
            success = self.snapshot_manager.save_snapshot(
                name, description, windows, displays
            )

            if success:
                self.load_snapshots()
                self.status_bar.showMessage(f"Snapshot '{name}' saved successfully")
            else:
                self.status_bar.showMessage("Failed to save snapshot")

        except Exception as e:
            self.status_bar.showMessage(f"Error capturing windows: {e}")

    def save_snapshot_dialog(self):
        """Show save snapshot dialog"""
        try:
            windows = self.window_manager.get_windows()
            displays = self.window_manager.get_displays()

            dialog = SnapshotDialog(self)
            if dialog.exec() == QDialog.DialogCode.Accepted:
                name, description = dialog.get_data()

                if not name:
                    QMessageBox.warning(
                        self, "Warning", "Please enter a snapshot name."
                    )
                    return

                # Save snapshot
                success = self.snapshot_manager.save_snapshot(
                    name, description, windows, displays
                )

                if success:
                    self.load_snapshots()
                    self.status_bar.showMessage(f"Snapshot '{name}' saved successfully")
                else:
                    QMessageBox.critical(self, "Error", "Failed to save snapshot.")

        except Exception as e:
            QMessageBox.critical(self, "Error", f"Error saving snapshot: {e}")

    def restore_selected_snapshot(self):
        """Restore the selected snapshot"""
        current_item = self.snapshot_list.currentItem()
        if not current_item:
            QMessageBox.warning(self, "Warning", "Please select a snapshot to restore.")
            return

        snapshot = current_item.data(Qt.ItemDataRole.UserRole)
        if not snapshot:
            return

        try:
            success = self.snapshot_manager.restore_snapshot(
                snapshot.name, self.window_manager
            )

            if success:
                self.status_bar.showMessage(
                    f"Snapshot '{snapshot.name}' restored successfully"
                )
                self.update_window_list()  # Refresh the window list
            else:
                self.status_bar.showMessage(
                    f"Failed to restore snapshot '{snapshot.name}'"
                )

        except Exception as e:
            QMessageBox.critical(self, "Error", f"Error restoring snapshot: {e}")

    def delete_selected_snapshot(self):
        """Delete the selected snapshot"""
        current_item = self.snapshot_list.currentItem()
        if not current_item:
            QMessageBox.warning(self, "Warning", "Please select a snapshot to delete.")
            return

        snapshot = current_item.data(Qt.ItemDataRole.UserRole)
        if not snapshot:
            return

        reply = QMessageBox.question(
            self,
            "Confirm Delete",
            f"Are you sure you want to delete snapshot '{snapshot.name}'?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )

        if reply == QMessageBox.StandardButton.Yes:
            try:
                success = self.snapshot_manager.delete_snapshot(snapshot.name)

                if success:
                    self.load_snapshots()
                    self.snapshot_info.clear()
                    self.status_bar.showMessage(
                        f"Snapshot '{snapshot.name}' deleted successfully"
                    )
                else:
                    self.status_bar.showMessage(
                        f"Failed to delete snapshot '{snapshot.name}'"
                    )

            except Exception as e:
                QMessageBox.critical(self, "Error", f"Error deleting snapshot: {e}")

    def show_window_manager(self):
        """Show window manager dialog"""
        # This could open a more detailed window management interface
        self.show()
        self.raise_()
        self.activateWindow()

    def show_about(self):
        """Show about dialog"""
        QMessageBox.about(
            self,
            "About SpaceWarp",
            "SpaceWarp v0.1.0\n\n"
            "A revolutionary multi-display window and app layout manager for macOS.\n\n"
            "Save and restore your window layouts with ease!",
        )

    def check_permissions(self):
        """Check and inform about required permissions"""
        missing = self.permissions_helper.get_missing_permissions()

        if missing:
            permission_text = " and ".join(missing)
            message = (
                f"SpaceWarp needs {permission_text} permission to work properly.\n\n"
            )
            message += (
                "Would you like to see instructions for granting these permissions?"
            )

            reply = QMessageBox.question(
                self,
                "Permissions Required",
                message,
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            )

            if reply == QMessageBox.StandardButton.Yes:
                self.show_permissions_instructions()

    def show_permissions_instructions(self):
        """Show detailed permissions instructions"""
        instructions = self.permissions_helper.request_permissions_instructions()

        dialog = QMessageBox(self)
        dialog.setWindowTitle("Permission Instructions")
        dialog.setText("Permissions Required")
        dialog.setDetailedText(instructions)
        dialog.setIcon(QMessageBox.Icon.Information)

        # Add button to open System Preferences
        open_prefs_btn = dialog.addButton(
            "Open System Preferences", QMessageBox.ButtonRole.ActionRole
        )
        open_prefs_btn.clicked.connect(self.permissions_helper.open_system_preferences)

        dialog.addButton(QMessageBox.StandardButton.Ok)
        dialog.exec()

    def refresh_permissions(self):
        """Refresh permission status"""
        self.window_manager._permissions_granted = (
            self.window_manager._check_permissions()
        )
        self.update_window_list()

        if self.window_manager._permissions_granted:
            self.status_bar.showMessage("Permissions granted successfully")
        else:
            self.status_bar.showMessage(
                "Permissions still required for full functionality"
            )
