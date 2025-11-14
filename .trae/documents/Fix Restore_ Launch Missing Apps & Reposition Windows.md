## Goal
- Restore a saved layout by checking running apps, repositioning open windows to snapshot coordinates, and launching missing apps then positioning their windows.

## Current Behavior
- `restore_snapshot` iterates windows and calls `WindowManager.restore_window` (`src/space_warp/snapshot_manager.py:196-209`).
- `restore_window` uses stored PID and a stubbed `_move_window` that prints AppleScript rather than executing it (`src/space_warp/window_manager.py:300-327`, `src/space_warp/window_manager.py:337-363`).
- No logic to launch missing applications; only `launch_app(bundle_id)` exists and requires bundle id (`src/space_warp/window_manager.py:378-389`).

## Implementation
- Window movement
  - Execute AppleScript to move/resize instead of printing in `_move_window`.
  - Target by window title when available: use System Events to set position/size of `(first window whose name is "<title>")`; fallback to `window 1`.
- App launching
  - Add `launch_app_by_name(app_name: str) -> bool` using `NSWorkspace.launchApplication_(app_name)` with fallback to `open -a`.
- Layout orchestration
  - Add `WindowManager.restore_layout(snapshot) -> bool`:
    - Collect `current_windows = self.get_windows()`.
    - For each `w` in `snapshot.windows`:
      - Find match by `app_name` and prefer same `window_title`; if found:
        - Compare current bounds vs snapshot; if different beyond small threshold, move window; unhide if minimized.
      - If no match:
        - Launch app by name; poll for window (`get_windows(app_name)`) until appears (timeout); then move it.
    - Emit `window_restored` per restored window and return success status.
- Manager integration
  - Change `SnapshotManager.restore_snapshot(...)` to call `window_manager.restore_layout(snapshot)` instead of per-window loop (`src/space_warp/snapshot_manager.py:202-208`).

## File Changes
- `src/space_warp/window_manager.py`
  - Implement AppleScript execution in `_move_window(pid, x, y, w, h, title=None)`.
  - Add `launch_app_by_name(app_name)`.
  - Add `restore_layout(snapshot)` with matching/launch-and-position logic.
- `src/space_warp/snapshot_manager.py`
  - Update `restore_snapshot(name, window_manager)` to delegate to `window_manager.restore_layout(snapshot)`.

## Behavior Details
- Matching logic prefers exact `window_title`; if no title match, uses first top-level window of the app.
- Position check uses absolute difference threshold (e.g., >2 px or size) before moving.
- Unhides apps if minimized/hidden to ensure windows are visible before moving.

## Testing
- Save a snapshot, move windows randomly, then restore: verify all windows are repositioned correctly.
- Close one app, restore snapshot: verify the app launches and its window is positioned.
- Change display arrangement minimally: confirm windows still place by absolute coordinates.

## Notes
- This relies on Accessibility and AppleScript; ensure permissions are granted (`src/space_warp/window_manager.py:55-64`).