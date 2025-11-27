#!/bin/bash

# Health Tracking Automation Script
# This script checks if a health tracking entry is needed and runs the Claude Code slash command

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if Ruby is available
if ! command -v ruby &> /dev/null; then
    echo "Error: Ruby not found. Please install Ruby first."
    exit 1
fi

# Find Claude Code CLI
CLAUDE_CMD=""
if command -v claude &> /dev/null; then
    CLAUDE_CMD="claude"
else
    # Search in ~/.local for the latest version (including symlinks)
    if [ -d "$HOME/.local" ]; then
        CLAUDE_CMD=$(find "$HOME/.local" -name claude \( -type f -o -type l \) 2>/dev/null | sort -V | tail -1)
    fi

    # If not found, check /usr/local/bin
    if [ -z "$CLAUDE_CMD" ] && [ -e "/usr/local/bin/claude" ]; then
        CLAUDE_CMD="/usr/local/bin/claude"
    fi
fi

if [ -z "$CLAUDE_CMD" ]; then
    echo "Error: Claude Code CLI not found. Please check installation."
    exit 1
fi

# Run the Ruby script to check if entry is needed
CHECK_RESULT=$(ruby "$SCRIPT_DIR/check_entry_needed.rb")

# Parse the JSON result
SKIP=$(echo "$CHECK_RESULT" | ruby -rjson -e "puts JSON.parse(STDIN.read)['skip']")
SLOT=$(echo "$CHECK_RESULT" | ruby -rjson -e "puts JSON.parse(STDIN.read)['slot']")
CURRENT_TIME=$(echo "$CHECK_RESULT" | ruby -rjson -e "puts JSON.parse(STDIN.read)['current_time']")
RECENT_ENTRY=$(echo "$CHECK_RESULT" | ruby -rjson -e "puts JSON.parse(STDIN.read)['recent_entry']")

# If we should skip, exit
if [ "$SKIP" = "true" ]; then
    echo "Skipping - recent entry already exists: $RECENT_ENTRY"
    exit 0
fi

# Change to the project directory and run the slash command
cd "$SCRIPT_DIR"

echo "Running health tracking for $SLOT slot at $CURRENT_TIME"
echo "---"

# Run the Claude Code slash command
# Note: This will open an interactive session
"$CLAUDE_CMD" /track-headache

