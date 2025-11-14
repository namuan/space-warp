<p style="text-align: center;">
  <img alt="Application Logo" src="https://github.com/namuan/space-warp/raw/main/assets/space-warp-icon.png" width="128px"/>
</p>
<h3 style="text-align: center;">SpaceWarp :: Name It, Save It, Warp Back Anytime</h3>

Save and restore your window layout, including position, size, and display assignment, as a quick snapshot.
Optimized for multi-display setups on macOS.

![](assets/app-intro.png)

## Features

- Capture the current layout of your application windows (across multiple displays)
- Save layouts as named snapshots in a local SQLite database
- Restore layouts later, attempting to reopen and reposition windows
- Provide quick access via a system tray icon and a main window

## Requirements

- macOS (Accessibility and Screen Recording permissions required)
- Python 3.11 or later
- uv (https://github.com/astral-sh/uv) installed

## Getting Started

Download this repo (either clone it or download the zip file)

Run the `install.command` script to install this application.

After installation, you can run the application from the $USER/Applications folder.

## Permissions (macOS)

SpaceWarp needs the following permissions to function correctly:

1. Accessibility (to enumerate, activate, and move windows)
2. Screen Recording (to read display information on newer macOS versions)

Grant them in: System Settings → Privacy & Security → Accessibility / Screen Recording. The app will prompt if not yet granted.

## Usage

Basic flow:
1. Arrange your windows the way you like across your displays.
2. Save a snapshot from the main window or the tray menu.
3. Later, restore the snapshot from the tray menu or main window. A restore report summarizes results.

Keyboard shortcuts (as configured by default in the config file):
- `Ctrl+Shift+S`: Save snapshot
- `Ctrl+Shift+R`: Restore last snapshot
- `Ctrl+Shift+M`: Show window manager

System tray menu provides quick access to save/restore, settings, showing the main window, and exiting.

## Configuration

Configuration is stored at `~/.spacewarp/config.yaml`. Default schema:

```yaml
start_minimized: true
auto_start: false
hotkeys:
  save_snapshot: "Ctrl+Shift+S"
  restore_last_snapshot: "Ctrl+Shift+R"
  toggle_window_manager: "Ctrl+Shift+M"
display:
  auto_adjust_missing_displays: true
  prompt_for_missing_displays: true
snapshots:
  auto_save_interval: 300
  max_snapshots: 50
```

Snapshot data is stored at `~/.spacewarp/snapshots.db` (SQLite), managed by the application.

## Troubleshooting

Application won’t start:
- Ensure Python 3.11+ is installed
- Ensure dependencies are installed: `uv sync`
- Launch from a terminal the first time to observe any errors: `uv run space-warp`

Windows not capturing/restoring:
- Verify Accessibility and Screen Recording permissions are granted
- Some applications may not expose windows via accessibility APIs
- Check the debug panel in the main window for logs

Multi‑display issues:
- Confirm macOS detects all displays and arrangement is correct
- Try creating a fresh snapshot after changing display configuration

Permissions issues:
- Open System Settings → Privacy & Security → Accessibility / Screen Recording and ensure SpaceWarp is enabled
- Restart the app after changing permissions

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Support

For issues and feature requests, please open an issue in the repository or contact the maintainers.
