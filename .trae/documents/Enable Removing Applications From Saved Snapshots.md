## Overview
- Add a UI action to remove an application from a selected snapshot’s windows list, then persist the change in the existing SQLite store and refresh the UI.
- Integrates into the current "Saved Snapshots" panel and uses the existing `SnapshotManager` for persistence.

## Current Flow Anchors
- Selection and details rendering: `src/space_warp/main_window.py:453-494` (`on_snapshot_selected`)
- Snapshot list + controls: `src/space_warp/main_window.py:167-209` (`create_snapshots_panel`)
- Snapshot saving/loading/deleting: `src/space_warp/main_window.py:426-441`, `551-616`, `664-699`
- Data model and persistence: `src/space_warp/snapshot_manager.py:16-27`, `75-127`, `128-185`, `186-203`, `283-341`
- Window layout restore uses `snapshot.windows`: `src/space_warp/window_manager.py:469-541`, `542-630`

## UI Changes
- Add a new button `Remove App...` beside existing snapshot controls in `create_snapshots_panel` (`src/space_warp/main_window.py:189-207`).
- Implement `remove_app_from_selected_snapshot()` in `MainWindow`:
  - Read the currently selected `Snapshot` from `QListWidgetItem` `UserRole` (`src/space_warp/main_window.py:455-485`).
  - Derive distinct `app_name` values from `snapshot.windows` and present a simple selection dialog:
    - Use a lightweight `QDialog` with a `QListWidget` or `QInputDialog.getItem` to choose one app.
  - On confirmation, invoke the persistence update (see below), reload snapshots, reselect the same snapshot by name, and refresh details.
- Status and UX:
  - If no snapshot selected, show a warning (`QMessageBox.warning`), consistent with existing patterns (`src/space_warp/main_window.py:496-499`, `664-669`).
  - If the chosen app is not present (race/refresh), show a message and no-op.

## Persistence Changes
- Add `remove_app_from_snapshot(name: str, app_name: str) -> bool` to `SnapshotManager` (`src/space_warp/snapshot_manager.py` near `delete_snapshot`).
  - Steps:
    - Fetch the snapshot by name (`get_snapshot`, `src/space_warp/snapshot_manager.py:128-154`).
    - Filter its `windows` list to exclude entries with `WindowInfo.app_name == app_name`.
    - Serialize the filtered list (`json.dumps([asdict(w) for w in filtered])`).
    - `UPDATE snapshots SET windows_json = ?, created_at = CURRENT_TIMESTAMP WHERE name = ? AND is_active = 1`.
    - Return `True` on success, `False` on exceptions; optionally emit `snapshot_saved` to align with existing refresh behavior.

## Wiring and Flow
- Button click → `remove_app_from_selected_snapshot()`:
  - Validate selection; build app list; prompt user; call `snapshot_manager.remove_app_from_snapshot(name, app_name)`.
  - Call `load_snapshots()` and `select_snapshot_by_name(name)` to refresh, consistent with `snapshot_saved` handling (`src/space_warp/main_window.py:260-268`, `426-441`, `442-448`).
  - Update `snapshot_info` by invoking `on_snapshot_selected()` indirectly via selection change.

## Validation
- Manual verification:
  - Select a snapshot, press `Remove App...`, choose an app.
  - `View Raw JSON` (`src/space_warp/main_window.py:503-539`) shows the app’s windows removed.
  - `Restore` now operates only on remaining apps; status bar and debug log reflect counts (`src/space_warp/main_window.py:617-663`).
- Optional unit test:
  - Create a `Snapshot` with two apps, call `remove_app_from_snapshot`, assert the stored `windows_json` excludes the target app and that `get_snapshot(name).windows` length decreases accordingly.

## Edge Cases
- Snapshot contains multiple windows for an app: all are removed.
- Resulting `windows` may be empty; keep snapshot valid and restorable (no-op restore).
- App name collisions due to localization or owner name differences: use exact `WindowInfo.app_name` values captured.
- If concurrent edits occur, use the latest DB state via `get_snapshot` before filtering.

## Implementation Notes
- Follow existing UI coding style (QWidgets, signals, and synchronous dialogs) as in `SnapshotDialog`.
- Keep database schema unchanged; update only `windows_json` and `created_at`.
- Avoid comments in code to match repository convention.
