#!/bin/bash

# Setup script for platform-specific scheduling
# Configures launchd on macOS or cron on Linux

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_SCRIPT="$SCRIPT_DIR/run-health-tracking.sh"

echo "Health Tracking Scheduling Setup"
echo "================================="
echo ""

# Detect platform
if [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macos"
    echo "Detected platform: macOS"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PLATFORM="linux"
    echo "Detected platform: Linux"
else
    echo "Error: Unsupported platform: $OSTYPE"
    exit 1
fi

echo ""

# Function to setup macOS launchd
setup_macos() {
    local LABEL="com.user.health-tracking"
    local PLIST_DIR="$HOME/Library/LaunchAgents"
    local PLIST_FILE="$PLIST_DIR/$LABEL.plist"

    echo "Setting up launchd for macOS..."
    echo ""

    # Create LaunchAgents directory if it doesn't exist
    mkdir -p "$PLIST_DIR"

    # Create the plist file
    cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>

    <key>ProgramArguments</key>
    <array>
        <string>$RUN_SCRIPT</string>
    </array>

    <key>StartCalendarInterval</key>
    <array>
        <dict>
            <key>Hour</key>
            <integer>9</integer>
            <key>Minute</key>
            <integer>30</integer>
            <key>Weekday</key>
            <integer>1</integer>
        </dict>
        <dict>
            <key>Hour</key>
            <integer>9</integer>
            <key>Minute</key>
            <integer>30</integer>
            <key>Weekday</key>
            <integer>2</integer>
        </dict>
        <dict>
            <key>Hour</key>
            <integer>9</integer>
            <key>Minute</key>
            <integer>30</integer>
            <key>Weekday</key>
            <integer>3</integer>
        </dict>
        <dict>
            <key>Hour</key>
            <integer>9</integer>
            <key>Minute</key>
            <integer>30</integer>
            <key>Weekday</key>
            <integer>4</integer>
        </dict>
        <dict>
            <key>Hour</key>
            <integer>9</integer>
            <key>Minute</key>
            <integer>30</integer>
            <key>Weekday</key>
            <integer>5</integer>
        </dict>
        <dict>
            <key>Hour</key>
            <integer>16</integer>
            <key>Minute</key>
            <integer>30</integer>
            <key>Weekday</key>
            <integer>1</integer>
        </dict>
        <dict>
            <key>Hour</key>
            <integer>16</integer>
            <key>Minute</key>
            <integer>30</integer>
            <key>Weekday</key>
            <integer>2</integer>
        </dict>
        <dict>
            <key>Hour</key>
            <integer>16</integer>
            <key>Minute</key>
            <integer>30</integer>
            <key>Weekday</key>
            <integer>3</integer>
        </dict>
        <dict>
            <key>Hour</key>
            <integer>16</integer>
            <key>Minute</key>
            <integer>30</integer>
            <key>Weekday</key>
            <integer>4</integer>
        </dict>
        <dict>
            <key>Hour</key>
            <integer>16</integer>
            <key>Minute</key>
            <integer>30</integer>
            <key>Weekday</key>
            <integer>5</integer>
        </dict>
    </array>

    <key>StandardOutPath</key>
    <string>$SCRIPT_DIR/logs/health-tracking.log</string>

    <key>StandardErrorPath</key>
    <string>$SCRIPT_DIR/logs/health-tracking.error.log</string>

    <key>WorkingDirectory</key>
    <string>$SCRIPT_DIR</string>
</dict>
</plist>
EOF

    echo "Created plist file: $PLIST_FILE"

    # Create logs directory
    mkdir -p "$SCRIPT_DIR/logs"

    # Unload existing job if it exists
    if launchctl list | grep -q "$LABEL"; then
        echo "Unloading existing job..."
        launchctl unload "$PLIST_FILE" 2>/dev/null || true
    fi

    # Load the new job
    echo "Loading launchd job..."
    launchctl load "$PLIST_FILE"

    echo ""
    echo "✓ Setup complete!"
    echo ""
    echo "Scheduled times (America/Detroit timezone):"
    echo "  - Monday-Friday at 9:30 AM"
    echo "  - Monday-Friday at 4:30 PM"
    echo ""
    echo "Logs will be written to:"
    echo "  - $SCRIPT_DIR/logs/health-tracking.log"
    echo "  - $SCRIPT_DIR/logs/health-tracking.error.log"
    echo ""
    echo "To unload (disable):"
    echo "  launchctl unload $PLIST_FILE"
    echo ""
    echo "To load (enable):"
    echo "  launchctl load $PLIST_FILE"
    echo ""
    echo "To test manually:"
    echo "  $RUN_SCRIPT"
}

# Function to setup Linux cron
setup_linux() {
    echo "Setting up cron for Linux..."
    echo ""

    # Create logs directory
    mkdir -p "$SCRIPT_DIR/logs"

    # Generate crontab entries
    local CRON_ENTRIES="# Health tracking - Morning check-in (9:30 AM America/Detroit, Mon-Fri)
30 9 * * 1-5 cd $SCRIPT_DIR && TZ=America/Detroit $RUN_SCRIPT >> $SCRIPT_DIR/logs/health-tracking.log 2>> $SCRIPT_DIR/logs/health-tracking.error.log

# Health tracking - Afternoon check-in (4:30 PM America/Detroit, Mon-Fri)
30 16 * * 1-5 cd $SCRIPT_DIR && TZ=America/Detroit $RUN_SCRIPT >> $SCRIPT_DIR/logs/health-tracking.log 2>> $SCRIPT_DIR/logs/health-tracking.error.log"

    echo "Add the following lines to your crontab:"
    echo ""
    echo "$CRON_ENTRIES"
    echo ""
    echo "To edit your crontab, run:"
    echo "  crontab -e"
    echo ""
    echo "Logs will be written to:"
    echo "  - $SCRIPT_DIR/logs/health-tracking.log"
    echo "  - $SCRIPT_DIR/logs/health-tracking.error.log"
    echo ""

    read -p "Would you like me to add these to your crontab now? (y/n) " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Get existing crontab
        (crontab -l 2>/dev/null || true; echo ""; echo "$CRON_ENTRIES") | crontab -
        echo "✓ Crontab entries added!"
    else
        echo "Skipped automatic installation. Please add the entries manually."
    fi

    echo ""
    echo "To test manually:"
    echo "  $RUN_SCRIPT"
}

# Run platform-specific setup
if [ "$PLATFORM" = "macos" ]; then
    setup_macos
else
    setup_linux
fi
