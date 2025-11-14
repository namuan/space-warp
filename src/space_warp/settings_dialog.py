from PyQt6.QtWidgets import (
    QDialog,
    QVBoxLayout,
    QTabWidget,
    QWidget,
    QFormLayout,
    QHBoxLayout,
    QCheckBox,
    QLineEdit,
    QSpinBox,
    QDialogButtonBox,
    QLabel,
)
from PyQt6.QtCore import Qt


class SettingsDialog(QDialog):
    def __init__(self, config, parent=None):
        super().__init__(parent)
        self.config = config
        self.setWindowTitle("Settings")
        self.resize(560, 420)
        root = QVBoxLayout(self)
        self.tabs = QTabWidget()
        root.addWidget(self.tabs)
        self.general_tab = QWidget()
        self.hotkeys_tab = QWidget()
        self.display_tab = QWidget()
        self.snapshots_tab = QWidget()
        self.tabs.addTab(self.general_tab, "General")
        self.tabs.addTab(self.hotkeys_tab, "Hotkeys")
        self.tabs.addTab(self.display_tab, "Display")
        self.tabs.addTab(self.snapshots_tab, "Snapshots")
        self._build_general()
        self._build_hotkeys()
        self._build_display()
        self._build_snapshots()
        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok
            | QDialogButtonBox.StandardButton.Apply
            | QDialogButtonBox.StandardButton.Cancel,
            Qt.Orientation.Horizontal,
            self,
        )
        buttons.accepted.connect(self._apply_and_accept)
        buttons.rejected.connect(self.reject)
        buttons.button(QDialogButtonBox.StandardButton.Apply).clicked.connect(self._apply)
        root.addWidget(buttons)
        self._apply_stylesheet()

    def _build_general(self):
        layout = QFormLayout(self.general_tab)
        self.start_minimized_chk = QCheckBox("Start minimized")
        self.start_minimized_chk.setChecked(self.config.get("start_minimized", True))
        layout.addRow(self.start_minimized_chk)
        self.auto_start_chk = QCheckBox("Launch at login")
        self.auto_start_chk.setChecked(self.config.get("auto_start", False))
        layout.addRow(self.auto_start_chk)

    def _build_hotkeys(self):
        layout = QFormLayout(self.hotkeys_tab)
        hk_save = self.config.get("hotkeys.save_snapshot", "Ctrl+Shift+S")
        hk_restore = self.config.get("hotkeys.restore_last_snapshot", "Ctrl+Shift+R")
        hk_toggle = self.config.get("hotkeys.toggle_window_manager", "Ctrl+Shift+M")
        self.hk_save_edit = QLineEdit(hk_save)
        self.hk_restore_edit = QLineEdit(hk_restore)
        self.hk_toggle_edit = QLineEdit(hk_toggle)
        layout.addRow(QLabel("Save snapshot"), self.hk_save_edit)
        layout.addRow(QLabel("Restore last snapshot"), self.hk_restore_edit)
        layout.addRow(QLabel("Toggle window manager"), self.hk_toggle_edit)

    def _build_display(self):
        layout = QFormLayout(self.display_tab)
        self.auto_adjust_chk = QCheckBox("Auto adjust for missing displays")
        self.auto_adjust_chk.setChecked(
            self.config.get("display.auto_adjust_missing_displays", True)
        )
        self.prompt_missing_chk = QCheckBox("Prompt when displays are missing")
        self.prompt_missing_chk.setChecked(
            self.config.get("display.prompt_for_missing_displays", True)
        )
        layout.addRow(self.auto_adjust_chk)
        layout.addRow(self.prompt_missing_chk)

    def _build_snapshots(self):
        layout = QFormLayout(self.snapshots_tab)
        self.auto_save_spin = QSpinBox()
        self.auto_save_spin.setRange(30, 3600)
        self.auto_save_spin.setSingleStep(30)
        self.auto_save_spin.setValue(self.config.get("snapshots.auto_save_interval", 300))
        self.max_snapshots_spin = QSpinBox()
        self.max_snapshots_spin.setRange(5, 500)
        self.max_snapshots_spin.setValue(self.config.get("snapshots.max_snapshots", 50))
        layout.addRow(QLabel("Auto-save interval (seconds)"), self.auto_save_spin)
        layout.addRow(QLabel("Max snapshots"), self.max_snapshots_spin)

    def _apply(self):
        self.config.set("start_minimized", self.start_minimized_chk.isChecked())
        self.config.set("auto_start", self.auto_start_chk.isChecked())
        self.config.set("hotkeys.save_snapshot", self.hk_save_edit.text().strip())
        self.config.set("hotkeys.restore_last_snapshot", self.hk_restore_edit.text().strip())
        self.config.set("hotkeys.toggle_window_manager", self.hk_toggle_edit.text().strip())
        self.config.set(
            "display.auto_adjust_missing_displays",
            self.auto_adjust_chk.isChecked(),
        )
        self.config.set(
            "display.prompt_for_missing_displays",
            self.prompt_missing_chk.isChecked(),
        )
        self.config.set("snapshots.auto_save_interval", int(self.auto_save_spin.value()))
        self.config.set("snapshots.max_snapshots", int(self.max_snapshots_spin.value()))

    def _apply_and_accept(self):
        self._apply()
        self.accept()

    def _apply_stylesheet(self):
        accent = "#2A82DA"
        bg = "#FFFFFF"
        fg = "#2D2D2D"
        muted = "#7A7A7A"
        border = "#D0D0D0"
        tab_bg = "#F5F5F5"
        css = f"""
        QDialog {{
            background-color: {bg};
            font-size: 15px;
        }}
        QTabWidget::pane {{
            border: 1px solid {border};
            border-radius: 8px;
            padding: 6px;
        }}
        QTabBar::tab {{
            background: {tab_bg};
            color: {fg};
            border: 1px solid {border};
            padding: 8px 16px;
            margin: 2px;
            border-top-left-radius: 6px;
            border-top-right-radius: 6px;
            font-size: 15px;
        }}
        QTabBar::tab:selected {{
            background: {accent};
            color: white;
        }}
        QGroupBox {{
            border: 1px solid {border};
            border-radius: 8px;
            margin-top: 12px;
        }}
        QLabel {{ color: {fg}; font-size: 15px; }}
        QCheckBox {{ color: {fg}; font-size: 15px; }}
        QLineEdit, QSpinBox {{
            background: #FFFFFF;
            color: {fg};
            border: 1px solid {border};
            border-radius: 6px;
            padding: 6px 8px;
            font-size: 15px;
        }}
        QLineEdit::placeholder {{ color: {muted}; }}
        QDialogButtonBox QPushButton {{
            background: {accent};
            color: white;
            border: none;
            padding: 10px 18px;
            border-radius: 6px;
            font-size: 16px;
            min-height: 36px;
        }}
        QDialogButtonBox QPushButton:hover {{
            background: #1E6FB9;
        }}
        QDialogButtonBox QPushButton:disabled {{
            background: #E0E0E0;
            color: #9A9A9A;
        }}
        """
        self.setStyleSheet(css)