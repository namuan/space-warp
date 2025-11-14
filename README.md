# SpaceWarp

Save and restore your entire app configuration—positions, sizes, even across multiple screens—as a "snapshot," and restore it instantly.

## Features

TBC

## Installation

### Requirements

- macOS 10.14 or later
- Python 3.11 or later
- `uv` package manager

### Install Dependencies

```bash
# Install dependencies using uv
uv sync

# Or install manually
uv add PyQt6 pyobjc-framework-Cocoa pyobjc-framework-ApplicationServices pyyaml
```

### Important: Permissions Required

SpaceWarp requires macOS permissions to function:

1. **Accessibility Permission** - For window management
2. **Screen Recording Permission** - For display information

The app will prompt you to grant these permissions on first launch. See [PERMISSIONS.md](PERMISSIONS.md) for detailed instructions.

## Usage

### Running the Application

```bash
# Run directly with Python
uv run python -m space_warp

# Or make it executable
chmod +x run.sh
./run.sh
```

### Basic Usage

1. **Launch the Application**: The app starts in the system tray
2. **Arrange Your Windows**: Set up your applications exactly how you want them
3. **Save a Snapshot**: Click "Save Snapshot" or use `Ctrl+Shift+S`
4. **Restore Later**: Select a snapshot from the list or system tray menu

### Keyboard Shortcuts

- `Ctrl+Shift+S`: Save current layout as snapshot
- `Ctrl+Shift+R`: Restore last used snapshot
- `Ctrl+Shift+M`: Show window manager

### System Tray Menu

Right-click the system tray icon for quick access to:

- Save current layout
- Restore saved layouts
- Show main window
- Application settings

## Development

### Project Structure

```
space-warp/
├── src/
│   └── space_warp/
│       ├── __init__.py          # Package initialization
│       ├── __main__.py          # Entry point
│       ├── main.py              # Main application
│       ├── config.py            # Configuration management
│       ├── window_manager.py    # Window capture/restore logic
│       ├── snapshot_manager.py  # Snapshot save/restore logic
│       ├── main_window.py       # Main GUI window
│       └── system_tray.py       # System tray integration
├── pyproject.toml               # Project configuration
└── README.md                    # This file
```

### Key Components

- **WindowManager**: Handles window capture and restoration using macOS APIs
- **SnapshotManager**: Manages saving and loading window layouts to SQLite
- **MainWindow**: PyQt6-based GUI for managing snapshots
- **SystemTrayIcon**: System tray integration for quick access
- **Config**: YAML-based configuration management

### Building for Distribution

```bash
# Install build dependencies
uv add --dev pyinstaller

# Build the application
pyinstaller --onefile --windowed \
  --name "SpaceWarp" \
  --icon "icon.icns" \
  src/space_warp/__main__.py
```

## Configuration

Configuration is stored in `~/.spacewarp/config.yaml`:

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

## Troubleshooting

### Application Won't Start

- Ensure Python 3.11+ is installed
- Check that all dependencies are installed: `uv sync`
- Verify macOS permissions for accessibility APIs

### Windows Not Capturing/Restoring

- Grant accessibility permissions in System Preferences > Security & Privacy > Accessibility
- Some applications may require additional permissions
- Check the application logs for specific errors

### Multi-Display Issues

- Ensure displays are properly detected in System Preferences
- Check display arrangement settings
- Verify snapshot was created with the same display configuration

### Permission Issues

- See [PERMISSIONS.md](PERMISSIONS.md) for detailed permission troubleshooting
- Run `uv run python demo_permissions.py` to check permission status
- Grant Accessibility and Screen Recording permissions in System Preferences

## License

This project is proprietary software. All rights reserved.

## Support

For support and feature requests, please contact the development team.
