"""
SpaceWarp - A revolutionary multi-display window and app layout manager for macOS
"""

__version__ = "0.1.0"
__author__ = "SpaceWarp Team"
__description__ = (
    "A revolutionary multi-display window and app layout manager for macOS"
)

from .main import main
from .config import Config
from .window_manager import WindowManager, WindowInfo, DisplayInfo
from .snapshot_manager import SnapshotManager, Snapshot
from .main_window import MainWindow
from .permissions import PermissionsHelper

__all__ = [
    "main",
    "Config",
    "WindowManager",
    "WindowInfo",
    "DisplayInfo",
    "SnapshotManager",
    "Snapshot",
    "MainWindow",
    "PermissionsHelper",
]
