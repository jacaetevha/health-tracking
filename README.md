# Health Tracking System

A system for tracking headaches and migraines by collecting daily health data including meals, sleep patterns, exercise, pain levels, and aura symptoms.

## Overview

This system provides:
- A Claude Code slash command (`/track-headache`) for conversational data entry
- Automated scheduling that runs twice daily on weekdays (9:30 AM and 4:30 PM America/Detroit)
- Smart detection to avoid duplicate entries within 1.5 hours
- Catch-up functionality for missed entries
- Structured JSON storage for easy analysis

## Files

- `.claude/commands/track-headache.md` - Claude Code slash command definition
- `check_entry_needed.rb` - Ruby script that checks if a new entry is needed
- `run-health-tracking.sh` - Wrapper script that runs the tracking command
- `setup-scheduling.sh` - Platform-specific scheduling setup (launchd/cron)
- `data/` - Directory where health tracking data is stored

## Setup

### 1. Install Prerequisites

- **Ruby**: Should already be installed on macOS. For Linux: `sudo apt install ruby`
- **Claude Code CLI**: Follow installation instructions at https://code.claude.com

### 2. Configure Scheduling

Run the setup script to configure automatic scheduling:

```bash
./setup-scheduling.sh
```

This will:
- **macOS**: Create and load a launchd job that runs at 9:30 AM and 4:30 PM on weekdays
- **Linux**: Provide crontab entries (with option to auto-install)

### 3. Test Manually

You can test the system manually at any time:

```bash
# Run the wrapper script (checks if entry is needed)
./run-health-tracking.sh

# Or run the slash command directly in Claude Code
claude /track-headache
```

## Usage

### Automated Usage

Once set up, the system will automatically:
1. Run at 9:30 AM and 4:30 PM on weekdays (Mon-Fri)
2. Check if an entry already exists within 1.5 hours
3. If no recent entry exists, launch Claude Code with the `/track-headache` command
4. Ask you questions conversationally and save your responses

### Manual Usage

You can also run tracking manually:

```bash
cd /Users/jrogers/personal/health-tracking
claude /track-headache
```

### Questions Asked

**Morning Session (9:30 AM):**
- What time did you go to bed last night?
- How many times did you wake up during the night?
- For each waking, approximately how long were you awake?
- What time did you wake up this morning?
- What did you eat for dinner last night? What time?
- Did you have any late-night snacks? If so, what and when?
- What exercising have you done since yesterday (or since Friday if Monday)?
- What stretching have you done since yesterday (or since Friday if Monday)?
- What is your current pain level? (0-10)
- What type of headache does it feel like?
- Are you experiencing auras?

**Afternoon Session (4:30 PM):**
- Sleep questions (only if morning entry is missing)
- What did you eat for breakfast? What time?
- What did you eat for lunch? What time?
- What snacks or drinks have you had today?
- What exercising have you done today?
- What stretching have you done today?
- What is your current pain level? (0-10)
- What type of headache does it feel like?
- Are you experiencing auras?

## Data Storage

Data is stored as JSON files in the `data/` directory with filenames in the format:

```
YYYY-MM-DD-HHmm.json
```

Example: `2025-11-14-0930.json`

### Data Format

```json
{
  "timestamp": "2025-11-14T09:30:00-05:00",
  "slot": "morning",
  "bedtime": "23:00",
  "wake_time": "07:00",
  "night_wakings": [
    {"time": "02:30", "duration_minutes": 15},
    {"time": "05:00", "duration_minutes": 10}
  ],
  "meals": [
    {
      "type": "dinner",
      "time": "18:30",
      "foods": ["chicken", "rice", "vegetables"]
    }
  ],
  "exercise": "30 min walk, 20 min weights",
  "stretching": "10 min yoga",
  "pain_level": 3,
  "headache_type": "tension headache",
  "aura": "none"
}
```

Sleep duration can be calculated programmatically from `bedtime`, `wake_time`, and `night_wakings`.

## Logs

Logs are written to the `logs/` directory:
- `logs/health-tracking.log` - Standard output
- `logs/health-tracking.error.log` - Error output

## Managing Scheduling

### macOS (launchd)

```bash
# Check if job is loaded
launchctl list | grep health-tracking

# Unload (disable)
launchctl unload ~/Library/LaunchAgents/com.user.health-tracking.plist

# Load (enable)
launchctl load ~/Library/LaunchAgents/com.user.health-tracking.plist

# Remove completely
rm ~/Library/LaunchAgents/com.user.health-tracking.plist
launchctl remove com.user.health-tracking
```

### Linux (cron)

```bash
# Edit crontab
crontab -e

# View current crontab
crontab -l

# Remove entries
# Edit with `crontab -e` and delete the health-tracking lines
```

## Multiple Computers

To use this on multiple computers:

1. Initialize a git repository:
   ```bash
   cd /Users/jrogers/personal/health-tracking
   git init
   ```

2. Create a private GitHub repository and push:
   ```bash
   git add .
   git commit -m "Initial health tracking setup"
   git remote add origin <your-private-repo-url>
   git push -u origin main
   ```

3. On your other computer, clone and run setup:
   ```bash
   git clone <your-private-repo-url>
   cd health-tracking
   ./setup-scheduling.sh
   ```

4. The `data/` directory will sync across computers via git, allowing continuous tracking.

## Tips

- The system won't create duplicate entries if you run it multiple times within 1.5 hours
- On Mondays, the morning session will ask about activity since Friday
- You can skip questions you don't remember by saying so
- The slash command is conversational - just answer naturally
- Data is in JSON format for easy programmatic analysis later
