"""
Snapshot manager for saving and restoring window layouts
"""

import json
import sqlite3
from datetime import datetime
from typing import Any
from dataclasses import dataclass, asdict
from PyQt6.QtCore import QObject, pyqtSignal

from .window_manager import WindowInfo, DisplayInfo
from .config import Config


@dataclass
class Snapshot:
    """A saved window layout snapshot"""

    id: int | None
    name: str
    description: str
    created_at: datetime
    windows: list[WindowInfo]
    displays: list[DisplayInfo]
    metadata: dict[str, Any]


class SnapshotManager(QObject):
    """Manages saving and restoring window layout snapshots"""

    snapshot_saved = pyqtSignal(str)  # snapshot name
    snapshot_restored = pyqtSignal(str)  # snapshot name
    snapshot_deleted = pyqtSignal(str)  # snapshot name

    def __init__(self, config: Config):
        super().__init__()
        self.config = config
        self.db_path = config.database_path
        self._init_database()

    def _init_database(self) -> None:
        """Initialize the SQLite database"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        # Create snapshots table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS snapshots (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT UNIQUE NOT NULL,
                description TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                windows_json TEXT NOT NULL,
                displays_json TEXT NOT NULL,
                metadata_json TEXT,
                is_active BOOLEAN DEFAULT 1
            )
        """)

        # Create snapshot_history table for auto-saves
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS snapshot_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                snapshot_id INTEGER,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                windows_json TEXT NOT NULL,
                FOREIGN KEY (snapshot_id) REFERENCES snapshots (id)
            )
        """)

        conn.commit()
        conn.close()

    def save_snapshot(
        self,
        name: str,
        description: str,
        windows: list[WindowInfo],
        displays: list[DisplayInfo],
        metadata: dict[str, Any] | None = None,
    ) -> bool:
        """Save a new snapshot"""
        try:
            # Convert data to JSON
            windows_json = json.dumps([asdict(w) for w in windows], default=str)
            displays_json = json.dumps([asdict(d) for d in displays], default=str)
            metadata_json = json.dumps(metadata or {}, default=str)

            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()

            # Check if snapshot with this name already exists
            cursor.execute("SELECT id FROM snapshots WHERE name = ?", (name,))
            existing = cursor.fetchone()

            if existing:
                # Update existing snapshot
                cursor.execute(
                    """
                    UPDATE snapshots
                    SET description = ?, windows_json = ?, displays_json = ?,
                        metadata_json = ?, created_at = CURRENT_TIMESTAMP
                    WHERE name = ?
                """,
                    (description, windows_json, displays_json, metadata_json, name),
                )
            else:
                # Insert new snapshot
                cursor.execute(
                    """
                    INSERT INTO snapshots (name, description, windows_json, displays_json, metadata_json)
                    VALUES (?, ?, ?, ?, ?)
                """,
                    (name, description, windows_json, displays_json, metadata_json),
                )

            conn.commit()
            conn.close()

            self.snapshot_saved.emit(name)
            return True

        except Exception as e:
            print(f"Error saving snapshot {name}: {e}")
            return False

    def get_snapshot(self, name: str) -> Snapshot | None:
        """Get a snapshot by name"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()

            cursor.execute(
                """
                SELECT id, name, description, created_at, windows_json,
                       displays_json, metadata_json
                FROM snapshots
                WHERE name = ? AND is_active = 1
            """,
                (name,),
            )

            row = cursor.fetchone()
            conn.close()

            if row:
                return self._row_to_snapshot(row)
            return None

        except Exception as e:
            print(f"Error getting snapshot {name}: {e}")
            return None

    def get_all_snapshots(self) -> list[Snapshot]:
        """Get all snapshots"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()

            cursor.execute("""
                SELECT id, name, description, created_at, windows_json,
                       displays_json, metadata_json
                FROM snapshots
                WHERE is_active = 1
                ORDER BY created_at DESC
            """)

            rows = cursor.fetchall()
            conn.close()

            return [self._row_to_snapshot(row) for row in rows]

        except Exception as e:
            print(f"Error getting all snapshots: {e}")
            return []

    def delete_snapshot(self, name: str) -> bool:
        """Delete a snapshot"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()

            cursor.execute("UPDATE snapshots SET is_active = 0 WHERE name = ?", (name,))

            conn.commit()
            conn.close()

            self.snapshot_deleted.emit(name)
            return True

        except Exception as e:
            print(f"Error deleting snapshot {name}: {e}")
            return False

    def restore_snapshot(self, name: str, window_manager) -> bool:
        snapshot = self.get_snapshot(name)
        if not snapshot:
            return False
        try:
            ok = False
            if hasattr(window_manager, "restore_layout"):
                ok = window_manager.restore_layout(snapshot)
            else:
                ok = all(window_manager.restore_window(w) for w in snapshot.windows)
            if ok:
                self.snapshot_restored.emit(name)
                return True
            return False
        except Exception as e:
            print(f"Error restoring snapshot {name}: {e}")
            return False

    @dataclass
    class RestoreReport:
        snapshot_name: str
        started_at: datetime
        finished_at: datetime
        total: int
        restored_count: int
        failed_count: int
        items: list[dict[str, Any]]

    def restore_snapshot_with_report(self, name: str, window_manager) -> RestoreReport | None:
        snapshot = self.get_snapshot(name)
        if not snapshot:
            return None
        started = datetime.now()
        try:
            if hasattr(window_manager, "restore_layout_with_report"):
                ok, items = window_manager.restore_layout_with_report(snapshot)
            else:
                # Fallback: derive items from per-window calls
                items: list[dict[str, Any]] = []
                ok = True
                for w in snapshot.windows:
                    restored = bool(window_manager.restore_window(w))
                    ok = ok and restored
                    items.append(
                        {
                            "app_name": w.app_name,
                            "window_title": w.window_title,
                            "restored": restored,
                            "launched": False,
                            "reason": None if restored else "restore_failed",
                        }
                    )
            finished = datetime.now()
            restored_count = sum(1 for it in items if it.get("restored"))
            failed_count = len(items) - restored_count
            report = SnapshotManager.RestoreReport(
                snapshot_name=name,
                started_at=started,
                finished_at=finished,
                total=len(items),
                restored_count=restored_count,
                failed_count=failed_count,
                items=items,
            )
            if ok:
                self.snapshot_restored.emit(name)
            return report
        except Exception as e:
            print(f"Error restoring snapshot {name}: {e}")
            return None

    def auto_save_snapshot(
        self, name: str = "Auto Save", max_history: int = 10
    ) -> bool:
        """Auto-save current layout"""
        # This would be called periodically to save the current state
        # Implementation would depend on window_manager integration
        pass

    def _row_to_snapshot(self, row) -> Snapshot:
        """Convert database row to Snapshot object"""
        (
            id,
            name,
            description,
            created_at,
            windows_json,
            displays_json,
            metadata_json,
        ) = row

        # Parse JSON data
        windows_data = json.loads(windows_json)
        displays_data = json.loads(displays_json)
        metadata_data = json.loads(metadata_json) if metadata_json else {}

        # Convert to objects
        windows = [WindowInfo(**w) for w in windows_data]
        displays = [DisplayInfo(**d) for d in displays_data]

        return Snapshot(
            id=id,
            name=name,
            description=description,
            created_at=datetime.fromisoformat(created_at),
            windows=windows,
            displays=displays,
            metadata=metadata_data,
        )

    def get_snapshot_names(self) -> list[str]:
        """Get list of all snapshot names"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()

            cursor.execute(
                "SELECT name FROM snapshots WHERE is_active = 1 ORDER BY name"
            )
            names = [row[0] for row in cursor.fetchall()]

            conn.close()
            return names

        except Exception as e:
            print(f"Error getting snapshot names: {e}")
            return []
