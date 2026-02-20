#!/bin/bash

#
# SpaceWarp Installation Script
# Builds and installs the app to ~/Applications
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# App info
APP_NAME="SpaceWarp"
APP_BUNDLE="${APP_NAME}.app"
APP_ID="com.spacewarp"
DEST_DIR="$HOME/Applications"

# Print functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Header
echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║         SpaceWarp Installer               ║"
echo "║     Window Layout Manager for macOS       ║"
echo "╚═══════════════════════════════════════════╝"
echo ""

# Function to reset permissions
reset_permissions() {
    info "Resetting app permissions..."
    
    # Reset Accessibility permissions
    if command -v tccutil &> /dev/null; then
        tccutil reset Accessibility "$APP_ID" 2>/dev/null || true
        tccutil reset ScreenCapture "$APP_ID" 2>/dev/null || true
        tccutil reset AppleEvents "$APP_ID" 2>/dev/null || true
        success "Permissions reset. You will be prompted to grant them on first launch."
    else
        warn "tccutil not found. Please reset permissions manually in System Settings > Privacy & Security."
    fi
    
    # Also remove old database to start fresh
    local db_path="$HOME/Library/Application Support/SpaceWarp/SpaceWarp.db"
    if [ -f "$db_path" ]; then
        info "Removing old database..."
        rm -f "$db_path"
        rm -f "${db_path}-journal" 2>/dev/null || true
        rm -f "${db_path}-wal" 2>/dev/null || true
        rm -f "${db_path}-shm" 2>/dev/null || true
    fi
}

# Get script directory (handles various execution methods)
get_script_dir() {
    # Try different methods to find the script location
    local SOURCE="${BASH_SOURCE[0]}"
    
    # Resolve symlinks
    while [ -L "$SOURCE" ]; do
        DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
        SOURCE="$(readlink "$SOURCE")"
        [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
    done
    
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    echo "$DIR"
}

SCRIPT_DIR=$(get_script_dir)
info "Script directory: $SCRIPT_DIR"

# Find project root (where Package.swift is located)
PROJECT_ROOT=""
if [ -f "$SCRIPT_DIR/Package.swift" ]; then
    PROJECT_ROOT="$SCRIPT_DIR"
elif [ -f "$(dirname "$SCRIPT_DIR")/Package.swift" ]; then
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
else
    # Search up the directory tree
    CURRENT_DIR="$SCRIPT_DIR"
    while [ "$CURRENT_DIR" != "/" ]; do
        if [ -f "$CURRENT_DIR/Package.swift" ]; then
            PROJECT_ROOT="$CURRENT_DIR"
            break
        fi
        CURRENT_DIR="$(dirname "$CURRENT_DIR")"
    done
fi

if [ -z "$PROJECT_ROOT" ] || [ ! -f "$PROJECT_ROOT/Package.swift" ]; then
    error "Package.swift not found. Please run this script from the SpaceWarp project directory."
fi

info "Project root: $PROJECT_ROOT"
cd "$PROJECT_ROOT"

# Verify Package.swift exists
if [ ! -f "Package.swift" ]; then
    error "Package.swift not found in $PROJECT_ROOT"
fi

# Check Swift installation
info "Checking for Swift..."
if ! command -v swift &> /dev/null; then
    error "Swift is not installed. Please install Xcode from the App Store."
fi

SWIFT_VERSION=$(swift --version | head -1)
info "Found: $SWIFT_VERSION"

# Check minimum Swift version (5.9+)
SWIFT_VER_NUM=$(swift --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
REQUIRED_VERSION="5.9"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$SWIFT_VER_NUM" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    warn "Swift $REQUIRED_VERSION or newer is recommended. You have $SWIFT_VER_NUM."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Clean previous builds
info "Cleaning previous builds..."
rm -rf .build/release/$APP_BUNDLE 2>/dev/null || true
rm -rf .build/release/$APP_NAME 2>/dev/null || true

# Resolve dependencies
info "Resolving dependencies..."
swift package resolve

# Build the project
info "Building $APP_NAME (Release mode)..."
echo ""
if swift build -c release 2>&1 | tee /tmp/spacewarp_build.log; then
    success "Build completed successfully!"
else
    error "Build failed. Check the output above for details."
fi
echo ""

# Verify build output
BUILD_DIR=".build/release"
if [ ! -f "$BUILD_DIR/$APP_NAME" ]; then
    error "Build output not found at $BUILD_DIR/$APP_NAME"
fi

# Create app bundle structure
info "Creating application bundle..."
APP_CONTENTS="$BUILD_DIR/$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"

mkdir -p "$APP_MACOS"
mkdir -p "$APP_RESOURCES"

# Copy executable
info "Copying executable..."
cp "$BUILD_DIR/$APP_NAME" "$APP_MACOS/$APP_NAME"

# Create Info.plist
info "Generating Info.plist..."
cat > "$APP_CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    
    <key>CFBundleExecutable</key>
    <string>SpaceWarp</string>
    
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    
    <key>CFBundleIdentifier</key>
    <string>com.spacewarp</string>
    
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    
    <key>CFBundleName</key>
    <string>SpaceWarp</string>
    
    <key>CFBundleDisplayName</key>
    <string>SpaceWarp</string>
    
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    
    <key>CFBundleVersion</key>
    <string>1</string>
    
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    
    <key>NSHighResolutionCapable</key>
    <true/>
    
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024 SpaceWarp. All rights reserved.</string>
    
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    
    <key>NSAccessibilityUsageDescription</key>
    <string>SpaceWarp needs accessibility access to manage window positions and sizes across your displays.</string>
    
    <key>NSScreenCaptureUsageDescription</key>
    <string>SpaceWarp needs screen recording access to detect display configurations and window positions.</string>
    
    <key>NSAppleEventsUsageDescription</key>
    <string>SpaceWarp needs automation access to control System Events for launching applications.</string>
    
    <key>LSUIElement</key>
    <false/>
</dict>
</plist>
PLIST

# Create PkgInfo
echo -n "APPL????" > "$APP_CONTENTS/PkgInfo"

# Create a simple app icon (placeholder)
info "Creating application icon..."
touch "$APP_RESOURCES/AppIcon.icns"

# Ensure destination directory exists
info "Preparing destination..."
mkdir -p "$DEST_DIR"

# Remove existing installation and reset permissions (no prompt)
if [ -d "$DEST_DIR/$APP_BUNDLE" ]; then
    info "Replacing existing installation..."
    reset_permissions
    rm -rf "$DEST_DIR/$APP_BUNDLE"
else
    # Reset permissions for fresh install too
    reset_permissions
fi

# Move app to Applications
info "Installing to $DEST_DIR..."
cp -R "$BUILD_DIR/$APP_BUNDLE" "$DEST_DIR/"

# Clean up build app bundle
rm -rf "$BUILD_DIR/$APP_BUNDLE"

# Verify installation
if [ -d "$DEST_DIR/$APP_BUNDLE" ]; then
    success "Installation complete!"
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo ""
    echo "  $APP_NAME has been installed to:"
    echo "  $DEST_DIR/$APP_BUNDLE"
    echo ""
    echo "  To launch:"
    echo "    • Open Finder and navigate to ~/Applications"
    echo "    • Double-click SpaceWarp"
    echo ""
    echo "  First run requirements:"
    echo "    • Grant Accessibility permission when prompted"
    echo "    • Grant Screen Recording permission when prompted"
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo ""
    
    # Offer to launch
    read -p "Launch $APP_NAME now? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        info "Launching $APP_NAME..."
        open "$DEST_DIR/$APP_BUNDLE"
    fi
else
    error "Installation failed - app bundle not found at destination"
fi
