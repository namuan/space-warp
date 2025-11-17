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
    QDockWidget,
    QTableWidget,
    QTableWidgetItem,
    QHeaderView,
)
from PyQt6.QtCore import Qt, QTimer
from PyQt6.QtGui import QAction, QKeySequence, QFont
from datetime import datetime
import json

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

        splitter = QSplitter(Qt.Orientation.Horizontal)
        self.splitter = splitter
        main_layout.addWidget(splitter)

        left_panel = self.create_current_windows_panel()
        splitter.addWidget(left_panel)

        # debug panel moved to dock

        right_panel = self.create_snapshots_panel()
        splitter.addWidget(right_panel)

        splitter.setSizes([600, 600])
        self.setup_logging_connections()
        self.create_debug_dock()

    def create_current_windows_panel(self):
        """Create the current windows panel"""
        group = QGroupBox("Current Windows")
        layout = QVBoxLayout(group)

        # Window list
        self.window_list = QListWidget()
        f1 = QFont()
        f1.setPointSize(16)
        self.window_list.setFont(f1)
        self.window_list.setStyleSheet("QListWidget { font-size: 16px; } QListWidget::item { padding: 6px 4px; }")
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
        f2 = QFont()
        f2.setPointSize(16)
        self.snapshot_list.setFont(f2)
        self.snapshot_list.setStyleSheet("QListWidget { font-size: 16px; } QListWidget::item { padding: 6px 4px; }")
        self.snapshot_list.itemSelectionChanged.connect(self.on_snapshot_selected)
        self.snapshot_list.itemDoubleClicked.connect(self.restore_selected_snapshot)
        layout.addWidget(self.snapshot_list)

        # Snapshot info
        self.snapshot_info = QTextEdit()
        self.snapshot_info.setMaximumHeight(220)
        self.snapshot_info.setReadOnly(True)
        layout.addWidget(self.snapshot_info)

        self.snapshot_windows_table = QTableWidget()
        self.snapshot_windows_table.setColumnCount(11)
        self.snapshot_windows_table.setHorizontalHeaderLabels([
            "",
            "App",
            "Title",
            "X",
            "Y",
            "Width",
            "Height",
            "Minimized",
            "Hidden",
            "Display",
            "PID",
        ])
        self.snapshot_windows_table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        self.snapshot_windows_table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self.snapshot_windows_table.setAlternatingRowColors(True)
        self.snapshot_windows_table.setSortingEnabled(True)
        self.snapshot_windows_table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Interactive)
        self.snapshot_windows_table.verticalHeader().setVisible(False)
        layout.addWidget(self.snapshot_windows_table)

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

        self.view_json_btn = QPushButton("View Raw JSON")
        self.view_json_btn.clicked.connect(self.view_raw_json)
        button_layout.addWidget(self.view_json_btn)

        self.view_debug_panel_btn = QPushButton("View Debug Panel")
        self.view_debug_panel_btn.clicked.connect(self.toggle_debug_panel)
        button_layout.addWidget(self.view_debug_panel_btn)

        layout.addLayout(button_layout)

        return group

    def create_debug_panel(self):
        group = QGroupBox("Debug")
        layout = QVBoxLayout(group)

        info_group = QGroupBox("Display & Window Coordinates")
        info_layout = QVBoxLayout(info_group)
        self.debug_info = QTextEdit()
        self.debug_info.setReadOnly(True)
        self.debug_info.setMinimumHeight(200)
        info_layout.addWidget(self.debug_info)
        layout.addWidget(info_group)

        log_group = QGroupBox("Restore Log")
        log_layout = QVBoxLayout(log_group)
        self.debug_log = QTextEdit()
        self.debug_log.setReadOnly(True)
        self.debug_log.setMinimumHeight(160)
        log_layout.addWidget(self.debug_log)
        layout.addWidget(log_group)

        button_layout = QHBoxLayout()
        self.debug_refresh_btn = QPushButton("Refresh Debug Info")
        self.debug_refresh_btn.clicked.connect(self.update_window_list)
        button_layout.addWidget(self.debug_refresh_btn)
        layout.addLayout(button_layout)

        return group

    def setup_logging_connections(self):
        try:
            self.window_manager.window_restore_started.connect(
                lambda app, title: self.append_debug_log(f"START {app} | {title}")
            )
            self.window_manager.window_restored.connect(
                lambda app, title: self.append_debug_log(f"OK    {app} | {title}")
            )
            self.window_manager.window_restore_failed.connect(
                lambda app, title, reason: self.append_debug_log(
                    f"FAIL  {app} | {title} reason={reason}"
                )
            )
            self.window_manager.window_launch_attempt.connect(
                lambda app, cmd: self.append_debug_log(f"LAUNCH TRY {app} cmd={cmd}")
            )
            self.window_manager.window_launch_result.connect(
                lambda app, ok, detail: self.append_debug_log(
                    f"LAUNCH {'OK' if ok else 'FAIL'} {app} detail={detail}"
                )
            )
            self.snapshot_manager.snapshot_restored.connect(
                lambda name: self.append_debug_log(f"SNAPSHOT OK {name}")
            )
            self.snapshot_manager.snapshot_saved.connect(
                lambda name: (self.load_snapshots(), self.select_snapshot_by_name(name))
            )
            self.snapshot_manager.snapshot_deleted.connect(
                lambda name: self.load_snapshots()
            )
        except Exception:
            pass

    def append_debug_log(self, line: str):
        try:
            ts = datetime.now().strftime("%H:%M:%S")
            self.debug_log.append(f"[{ts}] {line}")
        except Exception:
            pass

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
        if hasattr(self, "debug_dock"):
            view_menu.addAction(self.debug_dock.toggleViewAction())

        # Tools menu
        tools_menu = menubar.addMenu("Tools")

        capture_action = QAction("Capture Current Layout", self)
        capture_action.triggered.connect(self.capture_all_windows)
        tools_menu.addAction(capture_action)

    def create_debug_dock(self):
        dock = QDockWidget("Debug", self)
        dock.setObjectName("DebugDock")
        container = QWidget()
        layout = QVBoxLayout(container)
        info_group = QGroupBox("Display & Window Coordinates")
        info_layout = QVBoxLayout(info_group)
        self.debug_info = QTextEdit()
        self.debug_info.setReadOnly(True)
        self.debug_info.setMinimumHeight(200)
        info_layout.addWidget(self.debug_info)
        layout.addWidget(info_group)
        log_group = QGroupBox("Restore Log")
        log_layout = QVBoxLayout(log_group)
        self.debug_log = QTextEdit()
        self.debug_log.setReadOnly(True)
        self.debug_log.setMinimumHeight(160)
        log_layout.addWidget(self.debug_log)
        layout.addWidget(log_group)
        button_layout = QHBoxLayout()
        self.debug_refresh_btn = QPushButton("Refresh Debug Info")
        self.debug_refresh_btn.clicked.connect(self.update_window_list)
        button_layout.addWidget(self.debug_refresh_btn)
        layout.addLayout(button_layout)
        dock.setWidget(container)
        self.addDockWidget(Qt.DockWidgetArea.RightDockWidgetArea, dock)
        dock.hide()
        self.debug_dock = dock

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

            try:
                lines = []
                lines.append(f"Displays ({len(displays)}):")
                for d in displays:
                    lines.append(
                        f"- {d.name} id={d.display_id} main={d.is_main} x={d.x} y={d.y} w={d.width} h={d.height}"
                    )
                lines.append("")
                lines.append(f"Windows ({len(windows)}):")
                for w in windows:
                    lines.append(
                        f"- {w.app_name} | {w.window_title} pid={w.pid} x={w.x} y={w.y} w={w.width} h={w.height} display_id={w.display_id}"
                    )
                if hasattr(self, "debug_info"):
                    self.debug_info.setPlainText("\n".join(lines))
            except Exception as _:
                pass

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

    def select_snapshot_by_name(self, name: str):
        for i in range(self.snapshot_list.count()):
            it = self.snapshot_list.item(i)
            if it and it.text() == name:
                self.snapshot_list.setCurrentItem(it)
                break

    def on_window_selected(self):
        """Handle window selection"""
        pass  # Could show window details here

    def on_snapshot_selected(self):
        """Handle snapshot selection"""
        current_item = self.snapshot_list.currentItem()
        if current_item:
            snapshot = current_item.data(Qt.ItemDataRole.UserRole)
            if snapshot:
                lines = []
                lines.append(f"Name: {snapshot.name}")
                lines.append(
                    f"Created: {snapshot.created_at.strftime('%Y-%m-%d %H:%M:%S')}"
                )
                lines.append(f"Description: {snapshot.description}")
                lines.append("")

                lines.append(f"Displays ({len(snapshot.displays)}):")
                for d in snapshot.displays:
                    lines.append(
                        f"- {d.name} id={d.display_id} main={d.is_main} x={d.x} y={d.y} w={d.width} h={d.height}"
                    )

                display_name_map = {d.display_id: d.name for d in snapshot.displays}

                if snapshot.metadata:
                    lines.append("")
                    lines.append("Metadata:")
                    for k, v in snapshot.metadata.items():
                        lines.append(f"- {k}: {v}")

                self.snapshot_info.setPlainText("\n".join(lines))

                self.snapshot_windows_table.setRowCount(len(snapshot.windows))
                self.snapshot_windows_table.setColumnCount(11)
                self.snapshot_windows_table.setHorizontalHeaderLabels([
                    "",
                    "App",
                    "Title",
                    "X",
                    "Y",
                    "Width",
                    "Height",
                    "Minimized",
                    "Hidden",
                    "Display",
                    "PID",
                ])
                for i, w in enumerate(snapshot.windows):
                    disp_name = display_name_map.get(w.display_id, "?")
                    btn = QPushButton("✕")
                    btn.setFixedSize(24, 24)
                    btn.setStyleSheet(
                        "QPushButton { background-color: #b71c1c; color: white; border: none; border-radius: 4px; }"
                        "QPushButton:hover { background-color: #8b0000; }"
                    )
                    btn.clicked.connect(lambda _, a=w.app_name, s=snapshot.name: self._remove_app_from_snapshot_row(s, a))
                    container = QWidget()
                    lay = QHBoxLayout(container)
                    lay.setContentsMargins(0, 0, 0, 0)
                    lay.setAlignment(Qt.AlignmentFlag.AlignCenter)
                    lay.addWidget(btn)
                    self.snapshot_windows_table.setCellWidget(i, 0, container)
                    self.snapshot_windows_table.setRowHeight(i, 28)
                    self.snapshot_windows_table.setItem(i, 1, QTableWidgetItem(str(w.app_name)))
                    self.snapshot_windows_table.setItem(i, 2, QTableWidgetItem(str(w.window_title)))
                    self.snapshot_windows_table.setItem(i, 3, QTableWidgetItem(str(w.x)))
                    self.snapshot_windows_table.setItem(i, 4, QTableWidgetItem(str(w.y)))
                    self.snapshot_windows_table.setItem(i, 5, QTableWidgetItem(str(w.width)))
                    self.snapshot_windows_table.setItem(i, 6, QTableWidgetItem(str(w.height)))
                    self.snapshot_windows_table.setItem(i, 7, QTableWidgetItem("Yes" if w.is_minimized else "No"))
                    self.snapshot_windows_table.setItem(i, 8, QTableWidgetItem("Yes" if w.is_hidden else "No"))
                    self.snapshot_windows_table.setItem(i, 9, QTableWidgetItem(str(disp_name)))
                    self.snapshot_windows_table.setItem(i, 10, QTableWidgetItem(str(w.pid)))
                self.snapshot_windows_table.setColumnWidth(0, 40)
            else:
                self.snapshot_windows_table.setRowCount(0)
        else:
            self.snapshot_windows_table.setRowCount(0)

    def view_raw_json(self):
        current_item = self.snapshot_list.currentItem()
        if not current_item:
            QMessageBox.warning(self, "Warning", "Please select a snapshot.")
            return

        snapshot = current_item.data(Qt.ItemDataRole.UserRole)
        if not snapshot:
            return

        payload = {
            "name": snapshot.name,
            "description": snapshot.description,
            "created_at": snapshot.created_at.strftime("%Y-%m-%d %H:%M:%S"),
            "windows": [
                {
                    "app_name": w.app_name,
                    "window_title": w.window_title,
                    "x": w.x,
                    "y": w.y,
                    "width": w.width,
                    "height": w.height,
                    "is_minimized": w.is_minimized,
                    "is_hidden": w.is_hidden,
                    "display_id": w.display_id,
                    "pid": w.pid,
                }
                for w in snapshot.windows
            ],
            "displays": [
                {
                    "display_id": d.display_id,
                    "name": d.name,
                    "width": d.width,
                    "height": d.height,
                    "x": d.x,
                    "y": d.y,
                    "is_main": d.is_main,
                }
                for d in snapshot.displays
            ],
            "metadata": snapshot.metadata or {},
        }

        text = json.dumps(payload, indent=2)

        dlg = QDialog(self)
        dlg.setWindowTitle(f"Snapshot JSON: {snapshot.name}")
        dlg.resize(700, 500)

        v = QVBoxLayout(dlg)
        te = QTextEdit()
        te.setReadOnly(True)
        te.setPlainText(text)
        v.addWidget(te)

        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok,
            Qt.Orientation.Horizontal,
            dlg,
        )
        buttons.accepted.connect(dlg.accept)
        v.addWidget(buttons)

        dlg.exec()

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
                    self.select_snapshot_by_name(name)
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
            report = self.snapshot_manager.restore_snapshot_with_report(
                snapshot.name, self.window_manager
            )

            if report is None:
                self.status_bar.showMessage(
                    f"Failed to restore snapshot '{snapshot.name}'"
                )
                return

            if report.failed_count == 0:
                self.status_bar.showMessage(
                    f"Restored {report.restored_count}/{report.total} for '{snapshot.name}'"
                )
            else:
                failed = [f"{it['app_name']}" for it in report.items if not it.get("restored")]
                msg = f"Restored {report.restored_count}/{report.total}. Failed: {', '.join(sorted(set(failed)))}"
                self.status_bar.showMessage(msg)
                QMessageBox.warning(self, "Restore Completed With Failures", msg)

            self.update_window_list()  # Refresh the window list

            try:
                self.append_debug_log(
                    f"SNAPSHOT '{snapshot.name}' restored {report.restored_count}/{report.total}"
                )
                if report.failed_count:
                    failed_apps = ", ".join(sorted(set([it["app_name"] for it in report.items if not it.get("restored")])))
                    self.append_debug_log(f"SNAPSHOT failures: {failed_apps}")
            except Exception:
                pass

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

    def _remove_app_from_snapshot_row(self, snapshot_name: str, app_name: str):
        try:
            success = self.snapshot_manager.remove_app_from_snapshot(snapshot_name, app_name)
            if success:
                self.load_snapshots()
                self.select_snapshot_by_name(snapshot_name)
                self.status_bar.showMessage(f"Removed '{app_name}' from snapshot '{snapshot_name}'")
            else:
                QMessageBox.warning(self, "Warning", "Application not found or removal failed.")
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Error removing application: {e}")

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

    def toggle_debug_panel(self):
        if hasattr(self, "debug_dock"):
            if self.debug_dock.isVisible():
                self.debug_dock.hide()
                if hasattr(self, "view_debug_panel_btn"):
                    self.view_debug_panel_btn.setText("View Debug Panel")
            else:
                self.debug_dock.show()
                if hasattr(self, "view_debug_panel_btn"):
                    self.view_debug_panel_btn.setText("Hide Debug Panel")
