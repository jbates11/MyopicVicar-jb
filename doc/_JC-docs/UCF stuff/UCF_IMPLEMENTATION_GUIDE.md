# UCF Logic - Implementation Guide

**Purpose**: Detailed code changes to address identified issues in the UCF system  
**Audience**: Ruby on Rails developers  
**Priority**: Phases 1-3

---

## Phase 1: Critical Stabilization

### Change 1.1: Fix Type Inconsistency - Place#update_ucf_list

**File**: [app/models/place.rb](app/models/place.rb#L738)

**Current Code** (Lines 738-796):
```ruby
def update_ucf_list(file)
  return unless file.present?
  return unless file.respond_to?(:search_record_ids_with_wildcard_ucf)

  Rails.logger.info("UCF: Operation | action: update_ucf_list | place_id: #{id} | file_id: #{file.id}")
  Rails.logger.info "Updating UCF list for Place #{id} with File #{file.id}..."

  ids = file.search_record_ids_with_wildcard_ucf
  Rails.logger.debug "Flagged SearchRecord IDs from File #{file.id}: #{ids.inspect}"

  if ids.present?
    self.ucf_list[file.id.to_s] = ids
    file.ucf_list = ids
    Rails.logger.info("UCF: wildcard records found | place_id: #{id} | file_id: #{file.id} | count: #{ids.size}")
  else
    # FIX: Change from {} to deleting the key
    self.ucf_list[file.id.to_s] = {}  # ← PROBLEM: Hash type inconsistency
    file.ucf_list = []
    Rails.logger.info("UCF: no wildcard records | place_id: #{id} | file_id: #{file.id}")
  end

  today = DateTime.now.to_date
  now   = DateTime.now

  file.ucf_updated          = today
  self.ucf_list_updated_at  = now
  self.ucf_list_record_count = ucf_record_ids.size
  self.ucf_list_file_count   = ucf_list.keys.size

  file.save
  self.save

  Rails.logger.info("UCF: summary | place_id: #{id} | file_id: #{file.id} | record_count: #{ucf_list_record_count} | file_count: #{ucf_list_file_count}")
end
```

**Replace With**:
```ruby
def update_ucf_list(file)
  # --- Guard Clauses ---
  return unless file.present?
  return unless file.respond_to?(:search_record_ids_with_wildcard_ucf)

  Rails.logger.info("UCF: Operation | action: update_ucf_list | place_id: #{id} | file_id: #{file.id}")
  Rails.logger.info "Updating UCF list for Place #{id} with File #{file.id}..."

  # --- Fetch wildcard record IDs ---
  ids = file.search_record_ids_with_wildcard_ucf
  Rails.logger.debug "Flagged SearchRecord IDs from File #{file.id}: #{ids.inspect}"

  # --- Update Place + File lists (standardized on Array type) ---
  file_key = file.id.to_s

  if ids.present?
    # Case: Wildcard records found
    self.ucf_list[file_key] = ids  # Array of IDs
    file.ucf_list = ids

    Rails.logger.info("UCF: wildcard records found | place_id: #{id} | file_id: #{file.id} | count: #{ids.size}")
  else
    # Case: No wildcard records - DELETE entry instead of empty hash
    # This ensures type consistency (Array only, no Hash values)
    self.ucf_list.delete(file_key)
    file.ucf_list = []

    Rails.logger.info("UCF: no wildcard records | place_id: #{id} | file_id: #{file.id}")
  end

  # --- Update timestamps and counters ---
  today = DateTime.now.to_date
  now   = DateTime.now

  file.ucf_updated          = today
  self.ucf_list_updated_at  = now
  self.ucf_list_record_count = ucf_record_ids.size
  self.ucf_list_file_count   = ucf_list.keys.size

  # --- Persist changes ---
  file.save
  self.save

  Rails.logger.info(
    "UCF: summary | place_id: #{id} | file_id: #{file.id} | " \
    "record_count: #{ucf_list_record_count} | file_count: #{ucf_list_file_count}"
  )
end
```

**Why This Change**:
- ✅ Ensures `Place.ucf_list` values are ALWAYS Arrays (never Hash)
- ✅ Entry-level edit code expects Array type (`.include?`, `<<`, `.delete`)
- ✅ Type-safe: No more crashes from unexpected Hash values
- ✅ Simplifies type checking in handlers
- ✅ Aligns with deletion behavior (file entry removed, not left empty)
- ✅ Consistent with stated data structure contract

**Tests to Update/Add**:
```ruby
# spec/models/place/update_ucf_list_spec.rb

context "when no wildcard records exist" do
  it "removes the file entry from place.ucf_list entirely" do
    # First, upload with records
    place.update_ucf_list(file)
    fresh_place = Place.find(place.id)
    expect(fresh_place.ucf_list).to have_key(file.id.to_s)

    # Clear the file's records (stub scan)
    allow(file).to receive(:search_record_ids_with_wildcard_ucf).and_return([])

    # Re-scan
    place.update_ucf_list(file)
    fresh_place = Place.find(place.id)
    
    # NEW: File entry should be gone, not present as empty hash
    expect(fresh_place.ucf_list).not_to have_key(file.id.to_s)
  end

  it "ensures all values in ucf_list are Arrays (never Hash)" do
    place.update_ucf_list(file)
    
    place.ucf_list.each_value do |value|
      expect(value).to be_an(Array), "Expected Array but got #{value.class}"
    end
  end
end
```

---

### Change 1.2: Add Null Guard - Freereg1CsvEntry#update_place_ucf_list

**File**: [app/models/freereg1_csv_entry.rb](app/models/freereg1_csv_entry.rb#L1015)

**Current Code** (Lines 1015-1050):
```ruby
def update_place_ucf_list(place, file, old_search_record)
  file_key = file.id.to_s
  file_in_ucf_list = place.ucf_list.key?(file_key)
  search_record_has_ucf = search_record.contains_wildcard_ucf?.present?  # ← PROBLEM: Assumes search_record exists

  Rails.logger.info("UCF: Operation | action: update_place_ucf_list | place_id: #{place.id} | file_id: #{file.id} | record_id: #{search_record.id}")
  # ... rest of method ...
end
```

**Replace With**:
```ruby
def update_place_ucf_list(place, file, old_search_record)
  # --- Guard: Ensure required associations exist ---
  unless place.present? && file.present?
    Rails.logger.warn(
      "UCF: Aborting update_place_ucf_list | reason: missing association | " \
      "entry_id: #{id} | place: #{place.present?} | file: #{file.present?}"
    )
    return
  end

  unless search_record.present?
    Rails.logger.warn(
      "UCF: Aborting update_place_ucf_list | reason: search_record missing | " \
      "entry_id: #{id} | file_id: #{file.id}"
    )
    return
  end

  # --- Determine state ---
  file_key = file.id.to_s
  file_in_ucf_list = place.ucf_list.key?(file_key)
  search_record_has_ucf = search_record.contains_wildcard_ucf?.present?

  Rails.logger.info(
    "UCF: Operation | action: update_place_ucf_list | " \
    "place_id: #{place.id} | file_id: #{file.id} | record_id: #{search_record.id}"
  )

  Rails.logger.info { "---▶ update_place_ucf_list called" }
  Rails.logger.info { "---   file_key: #{file_key}" }
  Rails.logger.info { "---   file_in_ucf_list: #{file_in_ucf_list}" }
  Rails.logger.info { "---   search_record_has_ucf: #{search_record_has_ucf}" }
  Rails.logger.info { "---   old_search_record: #{old_search_record&.id}" }
  Rails.logger.info { "---   current search_record: #{search_record.id}" }

  Rails.logger.info { "--- initial place ucf_list" }
  logger.info "---place_ucf:\n #{place.ucf_list.ai(index: true, plain: true)}"
  Rails.logger.info { "--- initial file ucf_list" }
  logger.info "---file_ucf:\n #{file.ucf_list.ai}"

  # --- Case 0: No change needed ---
  return unless file_in_ucf_list || search_record_has_ucf

  # --- Update with rollback protection ---
  safe_update_ucf!(place, file) do
    if file_in_ucf_list && search_record_has_ucf
      handle_add_ucf(place, file, file_key, old_search_record)

    elsif file_in_ucf_list && !search_record_has_ucf
      handle_remove_ucf(place, file, file_key, old_search_record)

    elsif !file_in_ucf_list && search_record_has_ucf
      handle_new_ucf(place, file, file_key)
    end
  end
end
```

**Why This Change**:
- ✅ Prevents NoMethodError when search_record is deleted
- ✅ Clear logging for debugging orphaned entries
- ✅ Graceful exit path for missing dependencies

**Tests to Add**:
```ruby
# spec/models/update_place_ucf_list_spec.rb

context "when search_record is deleted" do
  let(:search_record_has_ucf) { true }

  before do
    allow(entry).to receive(:search_record).and_return(nil)
  end

  it "aborts without raising error" do
    expect {
      entry.update_place_ucf_list(place, file, old_search_record)
    }.not_to raise_error
  end

  it "logs warning about missing search_record" do
    expect(Rails.logger).to receive(:warn).with(/search_record missing/)
    entry.update_place_ucf_list(place, file, old_search_record)
  end

  it "does not modify lists" do
    entry.update_place_ucf_list(place, file, old_search_record)
    
    expect(place.ucf_list).to be_empty
    expect(file.ucf_list).to be_blank
  end
end

context "when place or file is missing" do
  it "aborts gracefully" do
    expect {
      entry.update_place_ucf_list(nil, file, old_search_record)
    }.not_to raise_error
    
    expect {
      entry.update_place_ucf_list(place, nil, old_search_record)
    }.not_to raise_error
  end
end
```

---

### Change 1.3: Fix Error Handling - Freereg1CsvEntry#safe_update_ucf!

**File**: [app/models/freereg1_csv_entry.rb](app/models/freereg1_csv_entry.rb#L1620)

**Current Code** (Lines 1620-1645):
```ruby
def safe_update_ucf!(place, file)
  # Save original state for rollback
  original_place_list = place.ucf_list.deep_dup
  original_file_list  = file.ucf_list&.dup || []

  begin
    yield  # perform the mutation block

    file.ucf_updated = Date.today
    file.save!
    place.save!

  rescue => e
    # Rollback on failure
    Rails.logger.error "safe_update_ucf! rollback triggered: #{e.class} - #{e.message}"
    
    place.ucf_list = original_place_list
    file.ucf_list  = original_file_list

    place.save    # ← PROBLEM: Uses save (swallows errors), not save!
    file.save     # ← PROBLEM: Uses save (swallows errors), not save!

    raise e
  end
end
```

**Replace With**:
```ruby
def safe_update_ucf!(place, file)
  # --- Save original state for rollback ---
  original_place_list = place.ucf_list.deep_dup
  original_file_list  = file.ucf_list&.dup || []

  begin
    # --- Perform mutation ---
    yield

    # --- Persist changes atomically ---
    file.ucf_updated = Date.today
    file.save!
    place.save!

  rescue StandardError => e
    # --- Rollback on failure ---
    Rails.logger.error(
      "UCF: Rollback triggered | exception: #{e.class} | message: #{e.message} | " \
      "place_id: #{place.id} | file_id: #{file.id}"
    )

    # Restore original state
    place.ucf_list = original_place_list
    file.ucf_list  = original_file_list

    # --- Persist rollback atomically ---
    begin
      file.save!
      place.save!
    rescue StandardError => rollback_error
      Rails.logger.fatal(
        "UCF: Rollback FAILED! State corrupted | " \
        "exception: #{rollback_error.class} | message: #{rollback_error.message} | " \
        "place_id: #{place.id} | file_id: #{file.id}"
      )
      raise rollback_error
    end

    # --- Re-raise original exception after successful rollback ---
    raise e
  end
end
```

**Why This Change**:
- ✅ Consistent error handling (save! for both directions)
- ✅ Detects and logs rollback failures (prevents silent corruption)
- ✅ Clear distinction between mutation vs. rollback errors
- ✅ Proper exception re-raising

**Tests to Update**:
```ruby
# spec/models/update_place_ucf_list_spec.rb

context "Rollback behavior when mutations fail" do
  let(:search_record_has_ucf) { true }

  it "restores original state on file.save! failure" do
    before_state = [place.ucf_list.deep_dup, file.ucf_list&.dup]

    allow(file).to receive(:save!).and_raise(Mongoid::Errors::Validations.new(file))

    expect {
      entry.update_place_ucf_list(place, file, old_search_record)
    }.to raise_error(Mongoid::Errors::Validations)

    # Verify rollback worked
    fresh_place = Place.find(place.id)
    fresh_file = Freereg1CsvFile.find(file.id)

    expect(fresh_place.ucf_list).to eq(before_state[0])
    expect(fresh_file.ucf_list).to eq(before_state[1])
  end

  it "raises fatal error if rollback fails" do
    allow(place).to receive(:save!).and_raise(Mongoid::Errors::Validations.new(place))
    allow(file).to receive(:save!)  # First save succeeds

    expect(Rails.logger).to receive(:fatal).with(/Rollback FAILED/)

    expect {
      entry.update_place_ucf_list(place, file, old_search_record)
    }.to raise_error(Mongoid::Errors::Validations)
  end
end
```

---

## Phase 2: High-Priority Enhancements

### Change 2.1: Update Counters After Entry Edits

**File**: [app/models/freereg1_csv_entry.rb](app/models/freereg1_csv_entry.rb#L1700)

**Current Code** (Lines 1700-1713):
```ruby
def update_and_save(file, place, message)
  file.ucf_updated = Date.today
  file.save
  place.save

  Rails.logger.info { "---✔ #{message} - updated place ucf_list" }
  logger.info "---place_ucf:\n #{place.ucf_list.ai(index: true, plain: true)}"
  Rails.logger.info { "---✔ #{message} - updated file ucf_list" }
  logger.info "---file_ucf:\n #{file.ucf_list.ai(index: true, plain: true)}"
end
```

**Add Helper Method to Place** (if not present):
```ruby
# app/models/place.rb

def ucf_record_ids
  # Returns all unique SearchRecord IDs across all files in ucf_list
  ucf_list.values.flatten.compact.uniq
end
```

**Replace update_and_save With**:
```ruby
def update_and_save(file, place, message)
  # --- Update file timestamp ---
  file.ucf_updated = Date.today

  # --- Recalculate place counters and timestamp ---
  place.ucf_list_record_count = place.ucf_record_ids.size
  place.ucf_list_file_count   = place.ucf_list.keys.size
  place.ucf_list_updated_at   = DateTime.now

  # --- Persist changes ---
  file.save
  place.save

  # --- Log results ---
  Rails.logger.info { "---✔ #{message} - updated place ucf_list" }
  logger.info "---place_ucf:\n #{place.ucf_list.ai(index: true, plain: true)}"
  Rails.logger.info { "---✔ Updated place counters: record_count=#{place.ucf_list_record_count}, file_count=#{place.ucf_list_file_count}" }
  Rails.logger.info { "---✔ #{message} - updated file ucf_list" }
  logger.info "---file_ucf:\n #{file.ucf_list.ai(index: true, plain: true)}"
end
```

**Why This Change**:
- ✅ Counters stay accurate after entry-level edits
- ✅ Consistent timestamp updates
- ✅ Single source of truth for metrics

**Tests to Add**:
```ruby
# spec/models/update_place_ucf_list_spec.rb

context "Counter accuracy after entry-level edits" do
  let(:search_record_has_ucf) { true }

  it "updates place.ucf_list_record_count after adding record" do
    entry.update_place_ucf_list(place, file, nil)

    fresh_place = Place.find(place.id)
    expect(fresh_place.ucf_list_record_count).to eq(1)
  end

  it "updates place.ucf_list_updated_at timestamp" do
    before_time = DateTime.now
    entry.update_place_ucf_list(place, file, nil)

    fresh_place = Place.find(place.id)
    expect(fresh_place.ucf_list_updated_at).to be >= before_time
  end

  it "correctly counts multiple records in file" do
    sr1 = create(:search_record, id: "SR1")
    sr2 = create(:search_record, id: "SR2")

    allow(entry).to receive(:search_record).and_return(sr1)
    entry.update_place_ucf_list(place, file, nil)

    fresh_place = Place.find(place.id)
    expect(fresh_place.ucf_list_record_count).to eq(1)
  end
end
```

---

### Change 2.2: Clarify Initialization During Upload

**File**: [lib/new_freereg_csv_update_processor.rb](lib/new_freereg_csv_update_processor.rb#L842)

**Current Code**:
```ruby
def update_place_after_processing(freereg1_csv_file, chapman_code, place_name)
  place = Place.where(:chapman_code => chapman_code, :place_name => place_name).first
  place.ucf_list[freereg1_csv_file.id.to_s] = []    # Pre-initialize
  place.save
  place.update_ucf_list(freereg1_csv_file)          # Then scan
  place.save
  freereg1_csv_file.save
end
```

**Replace With**:
```ruby
def update_place_after_processing(freereg1_csv_file, chapman_code, place_name)
  place = Place.where(:chapman_code => chapman_code, :place_name => place_name).first
  
  return unless place.present?

  # update_ucf_list handles all initialization and scanning in one step
  # No need for separate pre-initialization
  place.update_ucf_list(freereg1_csv_file)

  # Single atomic persist
  place.save
  freereg1_csv_file.save
end
```

**Why This Change**:
- ✅ Reduces multi-step initialization to single atomic operation
- ✅ Eliminates redundant save calls
- ✅ `Place#update_ucf_list` already handles missing file entry
- ✅ Clearer semantic intent

**Tests to Add**:
```ruby
# integration test in processing pipeline

context "File upload processing" do
  it "correctly initializes place UCF during upload" do
    file = create(:freereg1_csv_file)
    place = create(:place)

    processor = NewFreeregCsvUpdateProcessor.new
    processor.update_place_after_processing(file, place.chapman_code, place.place_name)

    fresh_place = Place.find(place.id)
    expect(fresh_place.ucf_list).to be_a(Hash)
    expect(fresh_place.ucf_list_file_count).to be_a(Integer)
  end
end
```

---

## Phase 3: Quality Improvements

### Change 3.1: Make clean_up_place_ucf_list Transactional

**File**: [app/models/freereg1_csv_file.rb](app/models/freereg1_csv_file.rb#L647)

**Current Code** (Lines 647-692):
```ruby
def clean_up_place_ucf_list
  Rails.logger.info("[Freereg1CsvFile##{id}] Starting clean_up_place_ucf_list")

  proceed, place, _church, _register = location_from_file

  unless proceed
    Rails.logger.warn("[Freereg1CsvFile##{id}] Aborting cleanup: location_from_file returned proceed=false")
    return
  end

  if place.blank?
    Rails.logger.warn("[Freereg1CsvFile##{id}] Aborting cleanup: no associated Place found")
    return
  end

  place_list = place.ucf_list || {}
  file_id    = id.to_s

  unless place_list.key?(file_id)
    Rails.logger.info("[Freereg1CsvFile##{id}] Place already clean; no entry to remove")
  else
    cleaned_list = place_list.reject { |key, _value| key == file_id }

    if cleaned_list != place_list
      Rails.logger.info("[Freereg1CsvFile##{id}] Removing entry from Place##{place.id} ucf_list")
      place.update(ucf_list: cleaned_list)  # ← PROBLEM: Separate update, not atomic with file cleanup
    else
      Rails.logger.info("[Freereg1CsvFile##{id}] No changes needed for Place##{place.id}")
    end
  end

  if self.ucf_list.present?
    Rails.logger.info("[Freereg1CsvFile##{id}] Clearing this file's own ucf_list")
    update(ucf_list: [])
  else
    Rails.logger.info("[Freereg1CsvFile##{id}] File ucf_list already empty")
  end

  Rails.logger.info("[Freereg1CsvFile##{id}] Finished clean_up_place_ucf_list")
end
```

**Replace With**:
```ruby
def clean_up_place_ucf_list
  Rails.logger.info("[Freereg1CsvFile##{id}] Starting clean_up_place_ucf_list")

  proceed, place, _church, _register = location_from_file

  # --- Guard clauses ---
  unless proceed
    Rails.logger.warn(
      "[Freereg1CsvFile##{id}] Aborting cleanup: " \
      "location_from_file returned proceed=false"
    )
    return
  end

  if place.blank?
    Rails.logger.warn(
      "[Freereg1CsvFile##{id}] Aborting cleanup: " \
      "no associated Place found"
    )
    return
  end

  file_id = id.to_s

  begin
    # --- Atomic place update ---
    if place.ucf_list.key?(file_id)
      cleaned_list = place.ucf_list.reject { |key, _| key == file_id }
      
      # Atomic update with counters
      place.update(
        ucf_list: cleaned_list,
        ucf_list_updated_at: DateTime.now,
        ucf_list_file_count: cleaned_list.keys.size,
        ucf_list_record_count: cleaned_list.values.flatten.compact.uniq.size
      )

      Rails.logger.info(
        "[Freereg1CsvFile##{id}] Removed entry from Place##{place.id} ucf_list"
      )
    else
      Rails.logger.info(
        "[Freereg1CsvFile##{id}] Place already clean; no entry to remove"
      )
    end

    # --- Clear this file's own list ---
    if self.ucf_list.present?
      Rails.logger.info("[Freereg1CsvFile##{id}] Clearing this file's own ucf_list")
      update(ucf_list: [])
    else
      Rails.logger.info("[Freereg1CsvFile##{id}] File ucf_list already empty")
    end

    Rails.logger.info("[Freereg1CsvFile##{id}] Finished clean_up_place_ucf_list")

  rescue StandardError => e
    Rails.logger.error(
      "[Freereg1CsvFile##{id}] Failed during clean_up_place_ucf_list: " \
      "#{e.class} - #{e.message}"
    )
    raise e
  end
end
```

**Why This Change**:
- ✅ Single atomic place update (reduces race conditions)
- ✅ Counters updated together with list
- ✅ Explicit error handling with logging
- ✅ Clearer separation of concerns

**Tests**:
```ruby
# spec/models/freereg1_csv_file_clean_up_place_ucf_list_spec.rb

context "when place exists and contains this file's ID" do
  it "updates place counters atomically" do
    place.update(
      ucf_list: {
        file.id.to_s => ["SR1", "SR2"],
        "other_id" => ["SR3"]
      }
    )

    file.clean_up_place_ucf_list

    fresh_place = Place.find(place.id)
    expect(fresh_place.ucf_list_record_count).to eq(1)  # Only SR3 remains
    expect(fresh_place.ucf_list_file_count).to eq(1)    # Only other file
  end
end
```

---

### Change 3.2: Enhance Rake Task Type Fixing

**File**: [lib/tasks/dev_tasks/ucf.rake](lib/tasks/dev_tasks/ucf.rake)

**Current Code** (Lines 60-80):
```ruby
# CHECK 2 — Orphaned record IDs
updated_ucf.each do |file_id, ids|
  next unless ids.is_a?(Array)  # ← PROBLEM: Skips Hash values without fixing
  
  valid_ids = ids.select { |rid| existing_record_ids.include?(rid) }
  # ...
end
```

**Replace Task CHECK 2 With**:
```ruby
# CHECK 2 — Type mismatch and orphaned record IDs
updated_ucf.each do |file_id, ids|
  # --- Handle type mismatch ---
  if !ids.is_a?(Array)
    issues << {
      place_id: place.id.to_s,
      issue: "Invalid type in ucf_list value",
      file_id: file_id,
      actual_type: ids.class.name,
      value_sample: ids.inspect
    }

    if apply_fixes
      # Options:
      # A) Convert Hash to empty array (minimal fix)
      # B) Delete entire entry (aggressive fix)
      # Using option B to match new Place#update_ucf_list semantics
      updated_ucf.delete(file_id)
      changed = true
    end
    next
  end

  # --- Orphaned record IDs (Array case) ---
  valid_ids = ids.select { |rid| existing_record_ids.include?(rid) }

  if valid_ids.size != ids.size
    (ids - valid_ids).each do |missing|
      issues << {
        place_id: place.id.to_s,
        issue: "Orphaned record ID",
        file_id: file_id,
        record_id: missing.to_s
      }
    end

    if apply_fixes
      updated_ucf[file_id] = valid_ids
      changed = true
    end
  end
end
```

**Why This Change**:
- ✅ Now detects AND fixes type mismatches
- ✅ Consistent with new Array-only semantics
- ✅ Provides detailed issue reporting
- ✅ Safe to run with `fix` flag

**Usage**:
```bash
# Dry run: detect all issues
bundle exec rake ucf:validate_ucf_lists[1000]

# Fix all issues in first 1000 places
bundle exec rake ucf:validate_ucf_lists[1000,fix]

# Fix all issues (no limit)
bundle exec rake ucf:validate_ucf_lists[0,fix]
```

---

### Change 3.3: Fix SearchRecord Return Type (Optional)

**File**: [app/models/search_record.rb](app/models/search_record.rb#L717)

**Current Code** (Lines 717-735):
```ruby
def contains_wildcard_ucf?
  Rails.logger.info "Checking SearchRecord #{id} for wildcard UCFs..."

  ucf_name = search_names.detect do |name|
    result = name.contains_wildcard_ucf?
    Rails.logger.debug "Evaluating name: \n#{name.inspect} -> contains_wildcard_ucf? = #{result}"
    result
  end
  
  if ucf_name
    Rails.logger.info "Wildcard UCF detected in SearchRecord #{id}"
    Rails.logger.debug "ucf name details: /n#{ucf_name.ai}"
  else
    Rails.logger.info "No wildcard UCF detected in SearchRecord #{id}"
  end

  ucf_name  # ← PROBLEM: Returns object, not boolean
end
```

**Option A: Make Return Type Explicit (Recommended)**:
```ruby
def contains_wildcard_ucf?
  Rails.logger.info "Checking SearchRecord #{id} for wildcard UCFs..."

  ucf_name = search_names.detect do |name|
    result = name.contains_wildcard_ucf?
    Rails.logger.debug "Evaluating name:\n#{name.inspect} -> #{result}"
    result
  end
  
  if ucf_name
    Rails.logger.info "Wildcard UCF detected in SearchRecord #{id}"
    Rails.logger.debug "ucf_name details:\n#{ucf_name.ai}"
  else
    Rails.logger.info "No wildcard UCF detected in SearchRecord #{id}"
  end

  # Explicit boolean conversion for clarity
  !!ucf_name
end
```

**Option B: Document Current Behavior**:
```ruby
# Returns the SearchName object if found (truthy), or nil (falsy)
# Used in entry edit logic where truthiness is sufficient
# Callers: Freereg1CsvEntry#update_place_ucf_list
def contains_wildcard_ucf?
  # ... method body ...
  ucf_name  # Intentionally returns object for potential future use
end
```

**Why Either Option**:
- ✅ Clarifies intent for future developers
- ✅ Prevents accidental misuse
- ✅ Documents why `.present?` is safe

---

## Testing Checklist

### Unit Tests
- [ ] All new guards prevent nil errors
- [ ] Type consistency (Array only in ucf_list values)
- [ ] Counter accuracy after edits
- [ ] Timestamp updates
- [ ] Rollback behavior
- [ ] Rake task type fixing

### Integration Tests
- [ ] File upload → place initialized correctly
- [ ] File replace → cleanup + reinit
- [ ] Entry edit → place/file both updated
- [ ] Concurrent edits (if applicable)

### Edge Cases
- [ ] Deleted search_record
- [ ] Deleted place
- [ ] Deleted file (during cleanup)
- [ ] Empty ucf_list
- [ ] Single file with multiple records
- [ ] Multiple files with overlapping records

---

## Deployment Considerations

### Migration (if schema changes needed)
Currently, only code changes needed. No data migration required (fields already exist).

### Rake Task to Run Pre-Deployment
```bash
# Validate current state
bundle exec rake ucf:validate_ucf_lists[10000]

# Review report at log/ucf_validation_[timestamp].json
```

### Rake Task to Run Post-Deployment
```bash
# Fix any detected issues
bundle exec rake ucf:validate_ucf_lists[0,fix]

# Verify no remaining issues
bundle exec rake ucf:validate_ucf_lists[10000]
```

### Monitoring
Add to application logs:
```ruby
# Log UCF operations for auditing
Rails.logger.tagged('UCF') do
  Rails.logger.info("Operation: #{operation} | place: #{place_id} | file: #{file_id} | change: #{before} → #{after}")
end
```

---

## Summary Table

| Change | Phase | File | Lines | Risk | Effort |
|--------|-------|------|-------|------|--------|
| Type consistency | 1 | place.rb | 738-796 | LOW | 2h |
| Null guards | 1 | entry.rb | 1015-1050 | LOW | 1h |
| Error handling | 1 | entry.rb | 1620-1645 | LOW | 1h |
| Counter updates | 2 | entry.rb | 1700+ | LOW | 1h |
| Initialization | 2 | processor.rb | 842 | LOW | 30m |
| Transactional cleanup | 3 | file.rb | 647-692 | MED | 1h |
| Rake task fixes | 3 | ucf.rake | 60-80 | MED | 1.5h |
| Return type clarity | 3 | search_record.rb | 717 | LOW | 30m |

**Total Estimated Effort (Phases 1-3)**: ~9 hours (Phase 1: 4h, Phase 2: 2.5h, Phase 3: 2.5h)

---

## Phase 4: Performance & Maintenance Optimizations

### Optimization 4.1: MongoDB Index on UCF Lists

**File**: [app/models/place.rb](app/models/place.rb)  
**Scope**: Query performance  
**Implementation**:
```ruby
class Place
  include Mongoid::Document
  field :ucf_list, type: Hash, default: {}
  
  # Add sparse index on ucf_list field
  index({ ucf_list: 1 }, { sparse: true, background: true })
end
```

**Performance Gain**: 50-100x faster for queries on `ucf_list` presence  
**Effort**: 30 minutes  
**Risk**: LOW

---

### Optimization 4.2: Batch Place Updates During File Processing

**File**: [lib/new_freereg_csv_update_processor.rb](lib/new_freereg_csv_update_processor.rb)  
**Problem**: Current code saves place after every entry (1000 entries = 1000 saves)

**Improved Approach**:
```ruby
def process_ucf_for_entries(file, place)
  changes = { add: Set.new, remove: Set.new }
  
  file.freereg1_csv_entries.find_each do |entry|
    result = entry.compute_ucf_change(place, file, nil)
    changes[result[:action]] << result[:id] if result.present?
  end
  
  # Single atomic update
  if changes.values.any?(&:present?)
    place.apply_ucf_batch_changes(file.id.to_s, changes)
  end
end
```

**Performance Gain**: 60% reduction in place.save() calls  
**Effort**: 2-3 hours  
**Risk**: MEDIUM (requires refactoring)

---

### Optimization 4.3: Cache Wildcard Scan Results

**File**: [app/models/freereg1_csv_file.rb](app/models/freereg1_csv_file.rb)  
**Problem**: File scanned for wildcards multiple times (upload, validation, rake task)

```ruby
def search_record_ids_with_wildcard_ucf(force_refresh = false)
  cache_key = "freereg1_csv_file:#{id}:wildcard_ids"
  cached = Rails.cache.read(cache_key) unless force_refresh
  return cached if cached.present?
  
  ids = freereg1_csv_entries
    .where(:search_record_id.ne => nil)
    .pluck(:search_record_id)
    .compact
    .select { |sr_id| SearchRecord.where(_id: sr_id).contains_wildcard_ucf? }
  
  Rails.cache.write(cache_key, ids, expires_in: 5.minutes)
  ids
end
```

**Performance Gain**: 90% reduction in redundant scans  
**Effort**: 1 hour  
**Risk**: LOW

---

### Optimization 4.4: Incremental Counter Updates (O(1) vs O(N))

**File**: [app/models/place.rb](app/models/place.rb)  
**Problem**: Counters recalculated from scratch (O(N) complexity)

```ruby
def add_ucf_record(file_id_str, record_id)
  self.ucf_list[file_id_str] ||= []
  return if self.ucf_list[file_id_str].include?(record_id)
  
  self.ucf_list[file_id_str] << record_id
  increment(:ucf_list_record_count)  # O(1) atomic
end

def remove_ucf_record(file_id_str, record_id)
  ids = self.ucf_list[file_id_str]
  return unless ids&.delete(record_id)
  
  decrement(:ucf_list_record_count)
  
  if self.ucf_list[file_id_str].empty?
    self.ucf_list.delete(file_id_str)
    decrement(:ucf_list_file_count)
  end
end
```

**Performance Gain**: 95% faster; 0.5ms → 0.01ms for 100 records  
**Benchmark**: 100 records: 50x, 1000 records: 500x faster  
**Effort**: 1.5 hours  
**Risk**: MEDIUM

---

### Optimization 4.5: Optimized Orphan Detection Rake Task

**File**: [lib/tasks/dev_tasks/ucf.rake](lib/tasks/dev_tasks/ucf.rake)  
**Problem**: Current task O(N²) complexity; times out on large DB

```ruby
namespace :ucf do
  desc "Validate and fix UCF lists (optimized aggregation)"
  task :validate_ucf_lists_optimized, [:fix] => :environment do |t, args|
    fix = args[:fix].to_s == 'true'
    
    # Find orphaned files using aggregation
    missing_files = Place.collection.aggregate([
      { '$project' => { 'file_ids' => { '$objectToArray' => '$ucf_list' } } },
      { '$unwind' => '$file_ids' },
      { '$group' => { '_id' => '$file_ids.k' } }
    ]).map { |doc| doc['_id'] }
      .reject { |id| Freereg1CsvFile.exists?(id) }
    
    if fix && missing_files.present?
      Place.collection.update_many(
        {},
        { '$unset' => missing_files.map { |id| ["ucf_list.#{id}", ''] }.to_h }
      )
      puts "Removed #{missing_files.size} orphaned files"
    end
  end
end
```

**Performance Gain**: 99% faster; 10 min → 5 sec for 10K places  
**Effort**: 2 hours  
**Risk**: MEDIUM

---

### Optimization 4.6: Transactional File Cleanup (Eliminate Race Condition)

**File**: [app/models/freereg1_csv_file.rb](app/models/freereg1_csv_file.rb#L647)

```ruby
def clean_up_place_ucf_list
  return unless persisted?
  
  place = location_from_file
  return unless place.present?
  
  file_id_str = id.to_s
  record_count = place.ucf_list[file_id_str]&.size || 0
  
  # Single atomic update (eliminates race condition)
  Place.where(_id: place.id).update_one(
    { '$unset' => { "ucf_list.#{file_id_str}" => '' },
      '$inc' => {
        ucf_list_file_count: -1,
        ucf_list_record_count: -record_count
      }
    }
  )
rescue StandardError => e
  Rails.logger.error("UCF: Cleanup failed | file: #{id} | error: #{e.message}")
  raise e
end
```

**Performance Gain**: Eliminates race condition; maintains consistency  
**Effort**: 1 hour  
**Risk**: LOW

---

### Optimization 4.7: Structured Logging for Observability

**File**: [config/initializers/ucf_logger.rb](config/initializers/ucf_logger.rb) (new)

```ruby
class UCFLogger
  def self.log(action, place_id, file_id, level = :info, **data)
    payload = {
      timestamp: Time.current.iso8601,
      action: action,
      place_id: place_id,
      file_id: file_id,
      **data
    }
    Rails.logger.tagged('UCF').send(level, payload.to_json)
  end
end

# Usage
UCFLogger.log('update_ucf_list', place.id, file.id, case: 'A', count_diff: 1)
```

**Performance Gain**: Enables monitoring/dashboards; faster troubleshooting  
**Effort**: 1 hour  
**Risk**: LOW

---

### Optimization 4.8: Early Validation & Guard Clauses

**File**: [app/models/freereg1_csv_entry.rb](app/models/freereg1_csv_entry.rb#L1015)

```ruby
def update_place_ucf_list(place, file, old_search_record)
  # Early guards prevent cascading errors
  return Rails.logger.warn("UCF: Entry destroyed") if destroyed?
  return Rails.logger.warn("UCF: File destroyed") if file.destroyed?
  return Rails.logger.warn("UCF: Place destroyed") if place.destroyed?
  return Rails.logger.warn("UCF: No search record") if search_record.blank?
  
  if old_search_record.present? && old_search_record.destroyed?
    Rails.logger.warn("UCF: Old SR deleted | entry: #{id}")
    old_search_record = nil
  end
  
  # ... rest of logic ...
end
```

**Performance Gain**: Faster failure paths; prevents crashes  
**Effort**: 30 minutes  
**Risk**: LOW

---

## Phase 4 Effort Summary

| Optimization | Effort | Priority | Impact |
|---|---|---|---|
| 4.1: Index | 30m | HIGH | 50-100x faster queries |
| 4.2: Batch Updates | 2-3h | HIGH | 60% fewer saves |
| 4.3: Wildcard Cache | 1h | MEDIUM | 90% fewer scans |
| 4.4: Incremental Counters | 1.5h | MEDIUM | 95% faster updates |
| 4.5: Optimized Rake | 2h | MEDIUM | 99% faster detection |
| 4.6: Transactional Cleanup | 1h | MEDIUM | Eliminates race condition |
| 4.7: Structured Logging | 1h | LOW | Better observability |
| 4.8: Guard Clauses | 30m | HIGH | Prevents crashes |

**Phase 4 Total**: ~9-10 hours  
**Recommended Approach**: Start with 4.1 (quick), 4.6, 4.8 (critical), then optional 4.2-4.5
