#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'time'

# Configuration
DATA_DIR = File.join(__dir__, 'data')
HTML_FILE = File.join(__dir__, 'index.html')

def load_health_data
  data_files = Dir.glob(File.join(DATA_DIR, '*.json')).sort.reverse

  data_files.map do |file|
    JSON.parse(File.read(file))
  rescue JSON::ParserError => e
    warn "Error parsing #{file}: #{e.message}"
    nil
  end.compact
end

def calculate_sleep_hours(bedtime, wake_time)
  return nil if bedtime.nil? || wake_time.nil?

  bed_hour, bed_min = bedtime.split(':').map(&:to_i)
  wake_hour, wake_min = wake_time.split(':').map(&:to_i)

  bed_minutes = bed_hour * 60 + bed_min
  wake_minutes = wake_hour * 60 + wake_min

  # If wake time is "earlier" than bedtime, it's the next day
  wake_minutes += 24 * 60 if wake_minutes < bed_minutes

  sleep_minutes = wake_minutes - bed_minutes
  (sleep_minutes / 60.0).round(1)
end

def calculate_summary(data)
  total_entries = data.length

  # Average sleep hours
  sleep_hours = data.map { |e| calculate_sleep_hours(e['bedtime'], e['wake_time']) }.compact
  avg_sleep = sleep_hours.empty? ? 'N/A' : (sleep_hours.sum / sleep_hours.length.to_f).round(1)

  # Average pain level
  pain_levels = data.map { |e| e['pain_level'] }.compact
  avg_pain = pain_levels.empty? ? 'N/A' : (pain_levels.sum / pain_levels.length.to_f).round(1)

  # Coffee days
  coffee_days = data.count { |e| e['coffee'] }

  # Most common headache type
  headache_types = data.each_with_object(Hash.new(0)) do |entry, hash|
    type = entry['headache_type']
    hash[type] += 1 if type && type != 'none'
  end

  most_common = headache_types.max_by { |_, count| count }
  common_headache = most_common ? "#{most_common[0]} (#{most_common[1]}x)" : 'None'

  # Average night wakings
  waking_counts = data.map { |e| e['night_wakings']&.length || 0 }
  avg_wakings = waking_counts.empty? ? 'N/A' : (waking_counts.sum / waking_counts.length.to_f).round(1)

  {
    total_entries: total_entries,
    avg_sleep: avg_sleep,
    avg_pain: avg_pain,
    coffee_days: "#{coffee_days}/#{total_entries}",
    common_headache: common_headache,
    avg_wakings: avg_wakings
  }
end

def get_pain_level_color(level)
  return 'bg-gray-100 text-gray-800' if level.nil?

  case level
  when 0..2 then 'bg-green-100 text-green-800'
  when 3..5 then 'bg-yellow-100 text-yellow-800'
  when 6..7 then 'bg-orange-100 text-orange-800'
  else 'bg-red-100 text-red-800'
  end
end

def generate_table_rows(data)
  # Sort by timestamp (newest first)
  sorted_data = data.sort_by { |e| Time.parse(e['timestamp']) }.reverse

  sorted_data.map do |entry|
    date = Time.parse(entry['timestamp']).strftime('%Y-%m-%d')
    sleep_hours = calculate_sleep_hours(entry['bedtime'], entry['wake_time'])
    night_wakings = entry['night_wakings']&.length || 0
    coffee_badge = entry['coffee'] ? 'bg-amber-100 text-amber-800' : 'bg-gray-100 text-gray-800'
    coffee_text = entry['coffee'] ? 'Yes' : 'No'
    pain_color = get_pain_level_color(entry['pain_level'])

    <<~HTML.chomp
                        <tr class="hover:bg-gray-50">
                            <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-900">#{date}</td>
                            <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-600">#{entry['slot'] || '-'}</td>
                            <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-600">#{entry['bedtime'] || '-'}</td>
                            <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-600">#{entry['wake_time'] || '-'}</td>
                            <td class="px-4 py-3 whitespace-nowrap text-sm font-medium text-gray-900">#{sleep_hours || '-'}</td>
                            <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-600">#{night_wakings}</td>
                            <td class="px-4 py-3 whitespace-nowrap text-sm">
                                <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full #{coffee_badge}">
                                    #{coffee_text}
                                </span>
                            </td>
                            <td class="px-4 py-3 whitespace-nowrap text-sm">
                                <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full #{pain_color}">
                                    #{entry['pain_level'] || '-'}
                                </span>
                            </td>
                            <td class="px-4 py-3 text-sm text-gray-600">#{entry['headache_type'] || '-'}</td>
                            <td class="px-4 py-3 text-sm text-gray-600">#{entry['exercise'] || '-'}</td>
                        </tr>
    HTML
  end.join("\n")
end

def update_html(summary, table_rows)
  html_template = <<~HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Health Tracking Dashboard</title>
        <script src="https://cdn.tailwindcss.com"></script>
    </head>
    <body class="bg-gray-50">
        <div class="container mx-auto px-4 py-8 max-w-7xl">
            <h1 class="text-4xl font-bold text-gray-800 mb-8">Health Tracking Dashboard</h1>

            <!-- Summary Section -->
            <div class="bg-white rounded-lg shadow-md p-6 mb-8">
                <h2 class="text-2xl font-semibold text-gray-700 mb-4">Summary</h2>
                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                    <div class="bg-blue-50 p-4 rounded-lg">
                        <p class="text-sm text-gray-600">Total Entries</p>
                        <p class="text-3xl font-bold text-blue-600">#{summary[:total_entries]}</p>
                    </div>
                    <div class="bg-green-50 p-4 rounded-lg">
                        <p class="text-sm text-gray-600">Avg Sleep Hours</p>
                        <p class="text-3xl font-bold text-green-600">#{summary[:avg_sleep]}</p>
                    </div>
                    <div class="bg-red-50 p-4 rounded-lg">
                        <p class="text-sm text-gray-600">Avg Pain Level</p>
                        <p class="text-3xl font-bold text-red-600">#{summary[:avg_pain]}</p>
                    </div>
                    <div class="bg-amber-50 p-4 rounded-lg">
                        <p class="text-sm text-gray-600">Coffee Days</p>
                        <p class="text-3xl font-bold text-amber-600">#{summary[:coffee_days]}</p>
                    </div>
                </div>

                <div class="mt-6 grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div class="bg-purple-50 p-4 rounded-lg">
                        <p class="text-sm text-gray-600 mb-2">Most Common Headache Type</p>
                        <p class="text-xl font-semibold text-purple-700">#{summary[:common_headache]}</p>
                    </div>
                    <div class="bg-indigo-50 p-4 rounded-lg">
                        <p class="text-sm text-gray-600 mb-2">Avg Night Wakings</p>
                        <p class="text-xl font-semibold text-indigo-700">#{summary[:avg_wakings]}</p>
                    </div>
                </div>
            </div>

            <!-- Raw Data Table -->
            <div class="bg-white rounded-lg shadow-md p-6">
                <h2 class="text-2xl font-semibold text-gray-700 mb-4">Raw Data</h2>
                <div class="overflow-x-auto">
                    <table class="min-w-full divide-y divide-gray-200">
                        <thead class="bg-gray-100">
                            <tr>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">Date</th>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">Slot</th>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">Bedtime</th>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">Wake Time</th>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">Sleep Hours</th>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">Night Wakings</th>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">Coffee</th>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">Pain Level</th>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">Headache Type</th>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">Exercise</th>
                            </tr>
                        </thead>
                        <tbody class="bg-white divide-y divide-gray-200">
    #{table_rows}
                        </tbody>
                    </table>
                </div>
            </div>

            <div class="mt-8 text-center text-sm text-gray-500">
                Last updated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S %Z')}
            </div>
        </div>
    </body>
    </html>
  HTML

  File.write(HTML_FILE, html_template)
  puts "Dashboard updated successfully at #{HTML_FILE}"
  puts "Last updated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S %Z')}"
end

# Main execution
begin
  puts "Loading health data from #{DATA_DIR}..."
  data = load_health_data

  if data.empty?
    puts "No data files found in #{DATA_DIR}"
    exit 1
  end

  puts "Loaded #{data.length} entries"

  puts "Calculating summary statistics..."
  summary = calculate_summary(data)

  puts "Generating table rows..."
  table_rows = generate_table_rows(data)

  puts "Updating HTML file..."
  update_html(summary, table_rows)

  puts "Done!"
rescue StandardError => e
  warn "Error: #{e.message}"
  warn e.backtrace
  exit 1
end
