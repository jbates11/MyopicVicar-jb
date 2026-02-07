# script/ucf_suite.rb
#
# UCF Combined Suite Runner
# -------------------------
# Runs the full UCF integrity suite:
#   1. Snapshot (optional)
#   2. Diff (snapshot vs DB)
#   3. Drift detection
#   4. Dry-run restore preview
#
# READ-ONLY except for snapshot creation.
#
# Usage:
#   rails runner script/ucf_suite.rb snapshot
#   rails runner script/ucf_suite.rb diff path/to/snapshot.json
#   rails runner script/ucf_suite.rb drift path/to/snapshot.json
#   rails runner script/ucf_suite.rb preview path/to/snapshot.json
#   rails runner script/ucf_suite.rb full path/to/snapshot.json
#

require "json"

MODE = ARGV[0]
SNAPSHOT_PATH = ARGV[1]

def banner(title)
  puts "\n============================================="
  puts "  #{title}"
  puts "=============================================\n"
end

# ---------------------------------------------------------
# 1. Snapshot
# ---------------------------------------------------------
def run_snapshot
  banner("UCF SNAPSHOT")

  timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
  output_path = Rails.root.join("tmp", "ucf_snapshot_#{timestamp}.json")

  snapshot = {
    generated_at: Time.now.utc,
    places: [],
    files: []
  }

  puts "→ Loading Place records..."
  Place.all.no_timeout.each do |place|
    snapshot[:places] << {
      id: place.id.to_s,
      ucf_list: place.ucf_list || {}
    }
  end

  puts "→ Loading File records..."
  Freereg1CsvFile.all.no_timeout.each do |file|
    snapshot[:files] << {
      id: file.id.to_s,
      ucf_list: file.ucf_list || []
    }
  end

  File.open(output_path, "w") do |f|
    f.write(JSON.pretty_generate(snapshot))
  end

  puts "📸 Snapshot saved to: #{output_path}"
end

# ---------------------------------------------------------
# 2. Diff (snapshot vs DB)
# ---------------------------------------------------------
def run_diff(snapshot)
  banner("UCF SNAPSHOT DIFF")

  snapshot_places = snapshot["places"] || []
  snapshot_files  = snapshot["files"]  || []

  puts "→ Diffing Places..."
  snapshot_places.each do |record|
    place = Place.where(id: record["id"]).first
    expected = record["ucf_list"] || {}
    actual   = place&.ucf_list || {}

    if place.nil?
      puts "❌ MISSING Place #{record['id']}"
      next
    end

    if expected != actual
      puts "⚠️  DIFF Place #{place.id}"
      puts "   Snapshot: #{expected.inspect}"
      puts "   Current:  #{actual.inspect}"
    end
  end

  puts "\n→ Diffing Files..."
  snapshot_files.each do |record|
    file = Freereg1CsvFile.where(id: record["id"]).first
    expected = record["ucf_list"] || []
    actual   = file&.ucf_list || []

    if file.nil?
      puts "❌ MISSING File #{record['id']}"
      next
    end

    if expected.sort != actual.sort
      puts "⚠️  DIFF File #{file.id}"
      puts "   Snapshot: #{expected.inspect}"
      puts "   Current:  #{actual.inspect}"
    end
  end

  puts "\n✓ Diff complete"
end

# ---------------------------------------------------------
# 3. Drift Detection
# ---------------------------------------------------------
def run_drift(snapshot)
  banner("UCF DRIFT DETECTION")

  drift_found = false

  def warn_drift(msg)
    puts "⚠️  DRIFT: #{msg}"
  end

  snapshot["places"].each do |record|
    place = Place.where(id: record["id"]).first
    expected = record["ucf_list"] || {}
    actual   = place&.ucf_list || {}

    if place.nil?
      warn_drift("Place #{record['id']} missing")
      drift_found = true
      next
    end

    if expected != actual
      warn_drift("Place #{place.id} differs")
      drift_found = true
    end
  end

  snapshot["files"].each do |record|
    file = Freereg1CsvFile.where(id: record["id"]).first
    expected = record["ucf_list"] || []
    actual   = file&.ucf_list || []

    if file.nil?
      warn_drift("File #{record['id']} missing")
      drift_found = true
      next
    end

    if expected.sort != actual.sort
      warn_drift("File #{file.id} differs")
      drift_found = true
    end
  end

  if drift_found
    puts "\n❌ DRIFT DETECTED"
  else
    puts "\n🎉 No drift detected"
  end
end

# ---------------------------------------------------------
# 4. Dry-Run Restore Preview
# ---------------------------------------------------------
def run_preview(snapshot)
  banner("UCF RESTORE DRY-RUN PREVIEW")

  snapshot["places"].each do |record|
    place = Place.where(id: record["id"]).first
    expected = record["ucf_list"] || {}
    actual   = place&.ucf_list || {}

    if place.nil?
      puts "❌ Would restore missing Place #{record['id']}"
      next
    end

    if expected != actual
      puts "🔄 Would update Place #{place.id}"
      puts "   Snapshot: #{expected.inspect}"
      puts "   Current:  #{actual.inspect}"
    end
  end

  snapshot["files"].each do |record|
    file = Freereg1CsvFile.where(id: record["id"]).first
    expected = record["ucf_list"] || []
    actual   = file&.ucf_list || []

    if file.nil?
      puts "❌ Would restore missing File #{record['id']}"
      next
    end

    if expected.sort != actual.sort
      puts "🔄 Would update File #{file.id}"
      puts "   Snapshot: #{expected.inspect}"
      puts "   Current:  #{actual.inspect}"
    end
  end

  puts "\n✓ Dry-run preview complete"
end

# ---------------------------------------------------------
# MAIN EXECUTION
# ---------------------------------------------------------
case MODE
when "snapshot"
  run_snapshot

when "diff", "drift", "preview", "full"
  if SNAPSHOT_PATH.nil?
    puts "❌ ERROR: You must provide a snapshot file path."
    exit 1
  end

  snapshot = JSON.parse(File.read(SNAPSHOT_PATH))

  run_diff(snapshot)    if MODE == "diff"
  run_drift(snapshot)   if MODE == "drift"
  run_preview(snapshot) if MODE == "preview"

  if MODE == "full"
    run_diff(snapshot)
    run_drift(snapshot)
    run_preview(snapshot)
  end

else
  puts "❌ Unknown mode: #{MODE}"
  puts "Valid modes: snapshot, diff, drift, preview, full"
end
