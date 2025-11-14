## Goal
- When a saved snapshot is selected, show a complete breakdown: per-display geometry, per-window details, and metadata. Keep storage unchanged.

## Current Behavior
- Selection handler only shows summary counts and description (`src/space_warp/main_window.py:361-371`).
- Snapshots already include full `windows` and `displays` objects (`src/space_warp/snapshot_manager.py:222-251`).

## Implementation
- Enhance `on_snapshot_selected` to render detailed information:
  - Displays: name, `display_id`, `is_main`, `x/y`, `width/height`.
  - Windows: `app_name`, `window_title`, `pid`, `x/y`, `width/height`, `display_id` and resolved display name.
  - Metadata: list key/value pairs when present.
- Keep using the existing `QTextEdit` (`self.snapshot_info`) and increase maximum height or switch to a `QSplitter` section for better readability; avoid new files.
- Add an optional "View Raw JSON" button beside snapshot controls to show the raw stored JSON in a modal dialog.

## File Changes
- `src/space_warp/main_window.py`:
  - Update `create_snapshots_panel` to add an optional "View Raw JSON" button.
  - Update `on_snapshot_selected` to build a formatted multiline string with displays and windows details.
- No changes to `src/space_warp/snapshot_manager.py` or storage schema.

## Data Mapping
- Build a `dict` mapping `display_id -> display.name` from `snapshot.displays` to annotate window entries.

## Testing
- Manual verification: save a snapshot, select it, confirm the details pane lists displays and each window with correct geometry and display names.

## Notes
- Storage remains SQLite at `~/.spacewarp/snapshots.db` (`src/space_warp/config.py:13-17`, `src/space_warp/config.py:117-120`).