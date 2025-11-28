# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a headache and migraine tracking system that collects daily health data through conversational data entry. The system runs automatically twice daily (9:30 AM and 4:30 PM America/Detroit timezone) and generates an HTML dashboard with trigger analysis.

## Architecture

### Data Flow

1. **Automated Scheduling**: Platform-specific scheduling (launchd/cron) triggers `run-health-tracking.sh` twice daily
2. **Entry Check**: `check_entry_needed.rb` determines if a new entry is needed (checks for duplicates within 1.5 hour window)
3. **Data Collection**: Claude Code slash command `/track-headache` conducts conversational interview and saves JSON files
4. **Dashboard Generation**: `update_dashboard.rb` processes all JSON data, calculates statistics, identifies potential triggers, and generates `index.html`
5. **Publishing**: Dashboard is uploaded to S3 bucket (wordsanddeeds.org/health-tracking.html)

### Key Components

- **`.claude/commands/track-headache.md`**: Defines the conversational data collection workflow
  - Handles two time slots: morning (9:30 AM) and afternoon (4:30 PM)
  - Morning: focuses on previous night's sleep, dinner, and current pain
  - Afternoon: focuses on day's meals, activity, and current pain (skips sleep questions if morning entry exists)
  - Detects missed entries and offers retroactive data collection
  - **CRITICAL**: Must use `TZ='America/Detroit' date` commands to get correct day of week for all date references

- **`check_entry_needed.rb`**: Ruby script that prevents duplicate entries
  - Outputs JSON with skip status and current slot information
  - Used by wrapper script to gate Claude Code invocations

- **`update_dashboard.rb`**: Dashboard generator with trigger analysis
  - Calculates summary statistics (avg sleep, pain levels, etc.)
  - Performs correlation analysis to identify potential triggers:
    - Coffee correlation (if painful days show >20% higher coffee rate)
    - Sleep quality (if sleep hours on painful days are 0.5h+ lower)
    - Night wakings (if wakings on painful days are 30%+ higher)
    - Food frequency analysis (foods appearing on 3+ painful days)
  - Generates Tailwind CSS-styled HTML dashboard
  - Uploads to S3 via AWS CLI

### Data Format

JSON files stored in `data/` directory with naming pattern: `YYYY-MM-DD-HHmm.json`

Required fields:
- `timestamp`: ISO 8601 format with timezone
- `slot`: "morning" or "afternoon"
- `bedtime`, `wake_time`: HH:MM format
- `night_wakings`: Array of `{time, duration_minutes}` objects
- `coffee`: Boolean (include in all entries)
- `water_intake_adequate`: Boolean (afternoon entries only)
- `meals`: Array of `{type, timestamp, foods}` objects
- `exercise`, `stretching`: Free text
- `pain_level`: 0-10 integer
- `headache_type`: String (options: nothing, tension headache, migraine, cluster headache, sinus headache, ice pick headache, other)
- `aura`: String description or "none"

## Common Commands

### Update Dashboard
```bash
ruby update_dashboard.rb
```
Regenerates `index.html` from all JSON data in `data/` and pushes to S3.

### Manually Trigger Data Collection
```bash
claude /track-headache
```

### Check if Entry is Needed
```bash
ruby check_entry_needed.rb
```
Outputs JSON indicating whether an entry should be created.

## User Baseline Habits

The user has consistent baseline habits that should be used as defaults:
- Drinks 1.2 liters of water daily with Celtic sea salt crystals
- Has 12 oz. coffee every morning

When collecting data, assume these defaults unless the user indicates otherwise.

## Important Implementation Notes

### Date Handling in `/track-headache`

**CRITICAL**: The track-headache command MUST correctly identify day of week for all dates. Previous instances have incorrectly called the current day by the wrong weekday name while getting "today" correct.

**Required approach**:
1. For current time: `TZ='America/Detroit' date '+%Y-%m-%d %H:%M:%S %Z (%A)'` - extract day from parentheses
2. For any specific date: `TZ='America/Detroit' date -d 'YYYY-MM-DD' '+%A'` - use this output directly
3. ALWAYS include day of week when presenting dates to user (e.g., "November 27th (Thursday)")

### Missed Entry Detection

When checking for missed entries:
- Check for gaps in 9:30 AM and 4:30 PM slots
- On Mondays, include previous weekend (Saturday/Sunday)
- Present all missed entries with correct day names
- Process retroactively if user requests

### Afternoon Entry Sleep Questions

For 4:30 PM entries, ONLY ask sleep questions if the 9:30 AM entry for the same day is missing. Check for existence of `data/YYYY-MM-DD-0930.json` before asking about previous night's sleep.

### Conversational Data Collection

The `/track-headache` command should:
- Be warm and empathetic (user is tracking health issues)
- Allow flexible natural language responses
- Parse responses into structured JSON
- Not make user feel bad for missing entries or incomplete answers
- Clearly indicate which date/time is being collected when doing retroactive entries
