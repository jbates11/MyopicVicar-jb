#!/usr/bin/env ruby
require 'optparse'
require 'fileutils'

options = { apply: false, verbose: false }
OptionParser.new do |opts|
  opts.banner = "Usage: replace_reload.rb [options]\n\nReplaces `.reload` usages in spec/ files with runtime-safe fresh fetches."
  opts.on('-a', '--apply', 'Apply changes in-place (will create .bak backups)') { options[:apply] = true }
  opts.on('-v', '--verbose', 'Verbose output') { options[:verbose] = true }
  opts.on('-h', '--help', 'Show this help') { puts opts; exit }
end.parse!

pattern = /(\b[a-z_][a-zA-Z0-9_]*?)\.reload\b/
files = Dir.glob('spec/**/*.rb')
total = 0

files.each do |path|
  text = File.read(path)
  matches = text.scan(pattern).flatten
  next if matches.empty?

  new_text = text.gsub(pattern) do
    var = Regexp.last_match(1)
    # Replace `obj.reload` with a runtime-safe fresh fetch: `(obj.class.find(obj.id))`
    "(#{var}.class.find(#{var}.id))"
  end

  if text == new_text
    next
  end

  total += matches.size
  if options[:apply]
    backup = "#{path}.bak"
    unless File.exist?(backup)
      FileUtils.cp(path, backup)
      puts "Backup created: #{backup}" if options[:verbose]
    end
    File.write(path, new_text)
    puts "Applied #{matches.size} replacement(s) in #{path}"
  else
    puts "Would replace #{matches.size} occurrence(s) in #{path}"
  end
end

puts "Done — #{total} occurrences found." unless total == 0
puts "No .reload occurrences found." if total == 0

exit 0
