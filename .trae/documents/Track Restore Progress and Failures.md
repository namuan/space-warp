## Goal
Provide clear progress while restoring a snapshot and a definitive summary of any apps/windows that failed to restart/restore.

## Current Behavior
- Snapshot restore entry points: `snapshot_manager.py:196` (`restore_snapshot`) and UI triggers in `system_tray.py:128` and `main_window.py:529`.
- Per-window success is signaled via `window_manager.py:49` (`window_restored`). Overall success emits `snapshot_manager.py:33` (`snapshot_restored`).
- Restoration logic lives in `window_manager.py:420` (`restore_layout`) and `window_manager.py:301` (`restore_window`). App launch is handled in `window_manager.py:389` (`launch_app_by_name`).
- Failures are only visible via console prints and a generic tray message.

## Changes
1. Add structured reporting
- Create data classes:
  - `RestoreItemResult { app_name, window_title, restored, launched, reason }`
  - `RestoreReport { snapshot_name, started_at, finished_at, total, restored_count, failed_count, items: RestoreItemResult[] }`
- Implement `SnapshotManager.restore_snapshot_with_report(name, window_manager) -> RestoreReport` that delegates to `WindowManager` and aggregates results. Keep existing `restore_snapshot(...) -> bool` for backward compatibility.

2. Emit progress/failure signals
- In `WindowManager` add:
  - `window_restore_started(str, str)` when starting a window restore
  - `window_restore_failed(str, str, str)` on failure with a short reason
- Optionally add snapshot-level progress: `snapshot_restore_progress(int completed, int total)` emitted from `SnapshotManager.restore_snapshot_with_report`.

3. Collect per-window outcomes
- Update `restore_window` and `restore_layout` to:
  - Emit `window_restore_started` before work
  - On success, keep existing `window_restored`
  - On failure (launch fail, window timeout, move/resize/minimize errors, permissions): emit `window_restore_failed` with reason and record a `RestoreItemResult`
- Accumulate all `RestoreItemResult` entries and return them to `SnapshotManager`.

4. UI integration
- `MainWindow`:
  - Add a non-blocking progress panel that lists `app_name`/`window_title` with status badges: Pending, Restoring, Restored, Failed.
  - Wire to `window_restore_started`, `window_restored`, `window_restore_failed`, and `snapshot_restore_progress`.
  - After completion, show a summary: `Restored X/Y, Failed Z` and allow expanding to see failed reasons.
- `SystemTray`:
  - Update restore action to call `restore_snapshot_with_report` and show a concise summary notification, e.g. `Restored 10/12; failed: Safari, Slack`.

5. Persistence
- Store `RestoreReport` in SQLite via `snapshot_history` as JSON in a new column (or inside `metadata_json` if you prefer to avoid schema changes) so users can review the last run.
- Provide a "View Last Restore Report" action in the tray/menu that opens the details panel.

## Failure reasons (examples)
- `launch_failed`: app couldn't be started
- `window_timeout`: window didn’t appear within wait period
- `move_failed` / `resize_failed`: AppleScript errors moving/resizing
- `permissions_missing`: Accessibility permissions not granted
- `minimize_failed`: AppleScript minimize/unminimize failed

## Implementation Notes
- Use ast-grep to insert new `pyqtSignal` declarations and to wrap key restore steps with emits and result recording for consistent refactoring.
- Do not change existing return types of `restore_snapshot(...)` to avoid breaking callers; introduce `restore_snapshot_with_report(...)`.
- Keep existing `print(...)` logs but prefer structured reasons in the report for user-facing output.

## Validation
- Run a restore with a mix of existing and non-running apps; confirm progress updates and that failures list the correct reasons.
- Verify tray and main window summaries reflect counts correctly.
- Ensure reports persist and can be reopened from the UI.

## Files to Touch
- `src/space_warp/window_manager.py`: add signals, collect results, emit progress/failures
- `src/space_warp/snapshot_manager.py`: add report types, aggregate results, new method
- `src/space_warp/main_window.py`: progress UI, signal wiring, summary view
- `src/space_warp/system_tray.py`: summary notification and optional report link
- `src/space_warp/db` (where SQLite helpers live): optional change to store report JSON