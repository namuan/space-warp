"""
Configuration management for SpaceWarp
"""

import yaml
from pathlib import Path
from typing import Any


class Config:
    """Configuration manager for the application"""

    def __init__(self):
        self.config_dir = Path.home() / ".spacewarp"
        self.config_file = self.config_dir / "config.yaml"
        self.data_file = self.config_dir / "snapshots.db"

        # Ensure config directory exists
        self.config_dir.mkdir(exist_ok=True)

        # Default configuration
        self.defaults = {
            "start_minimized": True,
            "auto_start": False,
            "hotkeys": {
                "save_snapshot": "Ctrl+Shift+S",
                "restore_last_snapshot": "Ctrl+Shift+R",
                "toggle_window_manager": "Ctrl+Shift+M",
            },
            "display": {
                "auto_adjust_missing_displays": True,
                "prompt_for_missing_displays": True,
            },
            "snapshots": {
                "auto_save_interval": 300,  # 5 minutes
                "max_snapshots": 50,
            },
        }

        self.config = self.load_config()

    def load_config(self) -> dict[str, Any]:
        """Load configuration from file or create default"""
        if self.config_file.exists():
            try:
                with open(self.config_file) as f:
                    config = yaml.safe_load(f)
                    # Merge with defaults to ensure all keys exist
                    return self._merge_config(self.defaults, config or {})
            except Exception as e:
                print(f"Error loading config: {e}")
                return self.defaults.copy()
        else:
            # Create default config file
            self.save_config(self.defaults)
            return self.defaults.copy()

    def save_config(self, config: dict[str, Any] | None = None) -> None:
        """Save configuration to file"""
        if config is None:
            config = self.config

        try:
            with open(self.config_file, "w") as f:
                yaml.dump(config, f, default_flow_style=False)
        except Exception as e:
            print(f"Error saving config: {e}")

    def get(self, key: str, default: Any = None) -> Any:
        """Get configuration value using dot notation"""
        keys = key.split(".")
        value = self.config

        for k in keys:
            if isinstance(value, dict) and k in value:
                value = value[k]
            else:
                return default

        return value

    def set(self, key: str, value: Any) -> None:
        """Set configuration value using dot notation"""
        keys = key.split(".")
        config = self.config

        # Navigate to the parent of the target key
        for k in keys[:-1]:
            if k not in config:
                config[k] = {}
            config = config[k]

        # Set the value
        config[keys[-1]] = value

        # Save to file
        self.save_config()

    def _merge_config(
        self, defaults: dict[str, Any], user_config: dict[str, Any]
    ) -> dict[str, Any]:
        """Recursively merge user config with defaults"""
        result = defaults.copy()

        for key, value in user_config.items():
            if (
                key in result
                and isinstance(result[key], dict)
                and isinstance(value, dict)
            ):
                result[key] = self._merge_config(result[key], value)
            else:
                result[key] = value

        return result

    @property
    def database_path(self) -> Path:
        """Get the path to the SQLite database file"""
        return self.data_file
