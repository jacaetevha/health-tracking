#!/usr/bin/env ruby
# frozen_string_literal: true

require 'time'
require 'json'

# Configuration
TIMEZONE = 'America/Detroit'
DATA_DIR = File.join(__dir__, 'data')
WINDOW_MINUTES = 90 # 1.5 hours

# Get current time in America/Detroit timezone
ENV['TZ'] = TIMEZONE
current_time = Time.now

# Determine which slot we're in
slot = current_time.hour < 13 ? 'morning' : 'afternoon'
target_time = if slot == 'morning'
                current_time.dup.tap { |t| t.instance_eval { @hour = 9; @min = 30 } }
                Time.new(current_time.year, current_time.month, current_time.day, 9, 30, 0, current_time.utc_offset)
              else
                Time.new(current_time.year, current_time.month, current_time.day, 16, 30, 0, current_time.utc_offset)
              end

# Create data directory if it doesn't exist
Dir.mkdir(DATA_DIR) unless Dir.exist?(DATA_DIR)

# Check for recent entries within the window
recent_entry = nil
current_date = current_time.strftime('%Y-%m-%d')

Dir.glob(File.join(DATA_DIR, "#{current_date}-*.json")).each do |file|
  # Extract timestamp from filename (format: YYYY-MM-DD-HHmm.json)
  basename = File.basename(file, '.json')
  match = basename.match(/(\d{4})-(\d{2})-(\d{2})-(\d{2})(\d{2})/)
  next unless match

  year, month, day, hour, minute = match.captures.map(&:to_i)
  file_time = Time.new(year, month, day, hour, minute, 0, current_time.utc_offset)

  # Calculate time difference in minutes
  time_diff_minutes = ((current_time - file_time) / 60).abs

  if time_diff_minutes <= WINDOW_MINUTES
    recent_entry = file
    break
  end
end

# Output result as JSON for easy parsing in shell script
result = {
  skip: !recent_entry.nil?,
  slot: slot,
  current_time: current_time.strftime('%Y-%m-%d %H:%M'),
  current_date: current_date,
  target_time: target_time.strftime('%H:%M'),
  recent_entry: recent_entry
}

puts JSON.generate(result)
