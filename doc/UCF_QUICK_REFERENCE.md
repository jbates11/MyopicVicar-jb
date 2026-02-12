# UCF Logic - Quick Reference Guide

**Purpose**: Executive summary for developers  
**Format**: Checklists, tables, bullet points  
**Audience**: All developers

---

## 🚀 Quick Start: What You Need to Know

### The Basics

UCF = Uncertified (Wildcard) Field records containing `*`, `_`, `?`, `{`, `}`

**Two synchronized lists with distinct types**:
```ruby
# File-level: ALWAYS an Array
Freereg1CsvFile.ucf_list  # Array: [record_id_1, record_id_2, ...]

# Place-level: Hash with Array values (never Hash values)
Place.ucf_list            # Hash: {file_id_str => [record_id_1, record_id_2, ...]}
                          # ⚠️ Values MUST be Arrays, never Hashes
```

**Three scenarios**:
1. CSV file upload (new batch)
2. CSV file replace (old file deleted + new file uploaded)
3. CSV entry edit (individual record modified)

**Current issues**:
- ⚠️ Type inconsistency: `Place.ucf_list[file_id]` is sometimes Array, sometimes Hash
- ⚠️ Null guards missing: Deleted search_record causes NoMethodError
- ⚠️ Error handling inconsistent: save vs. save! causes partial rollbacks
- ⚠️ Counters stale: Not updated after entry-level edits

---

## 🔧 Code Location Reference

| Component | File | Lines | Purpose |
|-----------|------|-------|---------|
| Place scan | [place.rb](app/models/place.rb#L738) | 738-796 | Scan file for wildcards, update lists |
| Entry edit | [entry.rb](app/models/freereg1_csv_entry.rb#L1015) | 1015-1050 | Handle individual entry UCF change |
| File handlers | [entry.rb](app/models/freereg1_csv_entry.rb#L1662) | 1662-1713 | Add/remove/create UCF handlers |
| File cleanup | [file.rb](app/models/freereg1_csv_file.rb#L647) | 647-692 | Remove UCF on file deletion |
| File upload | [processor.rb](lib/new_freereg_csv_update_processor.rb#L842) | 842 | Post-upload UCF initialization |
| Validation task | [ucf.rake](lib/tasks/dev_tasks/ucf.rake) | all | Detect/fix stale UCF lists |
| Controller entry | [entries_controller.rb](app/controllers/freereg1_csv_entries_controller.rb#L370) | 86, 381 | Trigger entry-level updates |

---

## 📋 Scenario Quick Reference

### Scenario 1: CSV File Upload (New)

```
User uploads file
  → File parsed, entries created
    → SearchRecords generated
      → update_place_after_processing()
        → place.update_ucf_list(file)
          → Scans all entries for wildcards
            → Sets place.ucf_list[file_id] = [SR1, SR2, ...]
            → Sets file.ucf_list = [SR1, SR2, ...]
```

---

### Scenario 2: CSV File Replacement (Full & Partial)

**Case 2.1: Full Re-upload (Complete Replacement)**
```
User replaces entire file (all new entries)
  → Old file.remove_batch()
    → file.clean_up_place_ucf_list()
      → place.ucf_list.delete(old_file_id)
    → Old file destroyed, SearchRecords destroyed
  → New file uploaded (same as Scenario 1)
  → place.update_ucf_list(new_file) scans for wildcards
```

**Case 2.2: Partial Re-upload (Modified Entries)**
```
User re-uploads with modifications to existing entries
  → File identified as existing (merge mode, update flag)
    → For each entry in new file:
      ├─ By entry_number: Find @all_existing_records match
      ├─ If matched: Update entry, call update_place_ucf_list() [A/B/0]
      └─ If not in new file: Mark for deletion
    → clean_up_unused_batches() destroys deleted entries
    → place.ucf_list updated incrementally
    → file.ucf_list reflects survivors only
```

**Case 2.3: Partial Re-upload (New Entries Only)**
```
User adds new entries to existing file (no modifications)
  → File identified as existing (merge mode, update flag)
    → For each entry in new file:
      ├─ By entry_number: Find @all_existing_records match
      ├─ If matched: Skip (Case 0, unchanged)
      └─ If not matched: Create new entry/SearchRecord [Case C/0]
    → Existing entries untouched
    → place.ucf_list includes new wildcard IDs
    → No cleanup phase (no deletions)
```

**Case 2.4: Partial Re-upload (Modifications + New + Deletions)**
```
User modifies existing, adds new, removes some entries
  → File identified as existing (merge mode, update flag)
    → Combines cases 2.2 + 2.3:
      ├─ Modified entries: update_place_ucf_list() [A/B/0]
      ├─ New entries: create + update_place_ucf_list() [C/0]
      └─ Deleted entries: marked for cleanup
    → clean_up_unused_batches() removes deleted entries
    → Final state: survivors + new entries with UCF synced
```

**Key code**:
```ruby
# Place#update_ucf_list(file)
ids = file.search_record_ids_with_wildcard_ucf
self.ucf_list[file.id.to_s] = ids
file.ucf_list = ids
place.save && file.save
```

---

### Scenario 2: CSV File Replace

```
User replaces file
  → Old file.remove_batch()
    → file.clean_up_place_ucf_list()
      → place.ucf_list.delete(old_file_id)
    → Old file destroyed
  → New file uploaded (same as Scenario 1)
```

**Key code**:
```ruby
# Freereg1CsvFile#clean_up_place_ucf_list
place.ucf_list.reject { |key, _| key == file_id }
place.update(ucf_list: cleaned_list)
update(ucf_list: [])
```

---

### Scenario 3: CSV Entry Edit

```
User edits entry
  → Entry#update_place_ucf_list()
    ├─ Determine: file in place? has_wildcard?
    ├─ Case A (yes, yes): handle_add_ucf()
    ├─ Case B (yes, no): handle_remove_ucf()
    ├─ Case C (no, yes): handle_new_ucf()
    └─ Case 0 (no, no): return
  → safe_update_ucf! (with rollback)
    → file.save! && place.save!
```

**Decision table**:
| file_in_place | has_wildcard | Action |
|---|---|---|
| Y | Y | Add record to lists |
| Y | N | Remove record from lists |
| N | Y | Create file entry |
| N | N | No change |

---

## ⚠️ Critical Issues & Fixes

### Issue 1: Type Inconsistency in Place.ucf_list VALUES (🔴 CRITICAL)

**Problem**:
```ruby
# Correct - value is Array:
place.ucf_list["file_123"] = [record_id_1, record_id_2]

# Incorrect - value is Hash (BAD):
place.ucf_list["file_123"] = {}  # ← Should never be Hash!
```

**Container types** (these are correct):
```ruby
Freereg1CsvFile.ucf_list.class  # ← Always Array
Place.ucf_list.class             # ← Always Hash
Place.ucf_list.values.first.class # ← Should ALWAYS be Array, never Hash
```

**Impact**: Entry edit fails with `NoMethodError: undefined method 'include?' for Hash:Hash`

**Fix**:
```ruby
# Always use Array (change in Place#update_ucf_list)
if ids.present?
  self.ucf_list[file_key] = ids
else
  self.ucf_list.delete(file_key)  # ← DELETE, don't set to {}
end
```

---

### Issue 2: No Null Guard (🔴 CRITICAL)

**Problem**:
```ruby
search_record_has_ucf = search_record.contains_wildcard_ucf?.present?
# If search_record is nil → NoMethodError
```

**Fix**:
```ruby
unless search_record.present?
  Rails.logger.warn("search_record missing for entry #{id}")
  return
end

search_record_has_ucf = search_record.contains_wildcard_ucf?.present?
```

---

### Issue 3: Inconsistent Error Handling (🟡 HIGH)

**Problem**:
```ruby
begin
  yield
  file.save!    # Raises on error
  place.save!
rescue => e
  place.save    # ← Silently swallows errors!
  file.save     # ← Silently swallows errors!
  raise e
end
```

**Fix**:
```ruby
rescue => e
  # ... rollback logic ...
  begin
    file.save!    # ← Use save!, not save
    place.save!   # ← Detect rollback failures
  rescue => rollback_error
    Rails.logger.fatal("Rollback FAILED: #{rollback_error}")
    raise rollback_error
  end
  raise e
end
```

---

### Issue 4: Stale Counters (🟡 HIGH)

**Problem**: Entry edits don't update counters
```ruby
def update_and_save(file, place, message)
  file.save
  place.save
  # Counters NOT updated!
end
```

**Fix**:
```ruby
def update_and_save(file, place, message)
  file.ucf_updated = Date.today
  place.ucf_list_record_count = place.ucf_record_ids.size
  place.ucf_list_file_count = place.ucf_list.keys.size
  place.ucf_list_updated_at = DateTime.now
  
  file.save
  place.save
end
```

---

## 🧪 Testing Checklist

### Must-Have Tests

- [ ] Type consistency: All `place.ucf_list` values are Arrays only
- [ ] Null guard: Entry edit with deleted search_record doesn't crash
- [ ] Error handling: Rollback persists on save failure
- [ ] Counters: Match actual record count after edits
- [ ] Scenario 1: Upload → lists populated correctly
- [ ] Scenario 2: Replace → old removed, new added
- [ ] Scenario 3: Edit → both lists updated atomically

### Nice-to-Have Tests

- [ ] Concurrent edits (race condition)
- [ ] Partial failures (cleanup succeeds, init fails)
- [ ] Edge cases (empty file, all wildcards, no wildcards)

---

## 📊 Data Validation Queries

### Check for Type Mismatches

```ruby
# Find all places with Hash-type values in ucf_list
Place.all.select { |p| p.ucf_list.any? { |_, v| v.is_a?(Hash) } }
```

### Check for Orphaned File IDs

```ruby
# Find ucf_list entries referencing nonexistent files
Place.all.each do |place|
  place.ucf_list.keys.each do |file_id|
    unless Freereg1CsvFile.where(id: file_id).exists?
      puts "Orphaned file in Place#{place.id}: #{file_id}"
    end
  end
end
```

### Check for Desynchronization

```ruby
# Find where file and place lists don't match
Place.all.each do |place|
  place.ucf_list.each do |file_id, record_ids|
    file = Freereg1CsvFile.find(file_id)
    unless file.ucf_list.sort == record_ids.sort
      puts "Mismatch in Place#{place.id}, File#{file_id}"
      puts "  Place: #{record_ids.sort.inspect}"
      puts "  File: #{file.ucf_list.sort.inspect}"
    end
  end
end
```

### Run Validation Task

```bash
# Detect issues (dry run)
bundle exec rake ucf:validate_ucf_lists[1000]

# Review report
cat log/ucf_validation_*.json | jq '.' | less

# Fix issues
bundle exec rake ucf:validate_ucf_lists[1000,fix]
```

---

## 🛠️ Implementation Roadmap

### Phase 1: Stabilize (4-6 hours)

**Priority**: 🔴 Do immediately

- [ ] Fix type inconsistency in `Place#update_ucf_list`
  - Change: `self.ucf_list[file_id] = {}` → `self.ucf_list.delete(file_id)`
  
- [ ] Add null guards in `Freereg1CsvEntry#update_place_ucf_list`
  - Add: Check `search_record.present?` before use
  
- [ ] Fix error handling in `safe_update_ucf!`
  - Change: `place.save` → `place.save!` on rollback

**Tests needed**: 6-8 unit tests

---

### Phase 2: Enhance (2-3 hours)

**Priority**: 🟡 Next sprint

- [ ] Update counters in `update_and_save`
  - Add: Recalculate `ucf_list_record_count` and `ucf_list_file_count`
  
- [ ] Simplify initialization in `update_place_after_processing`
  - Remove: Pre-init step, let `update_ucf_list` handle it
  
- [ ] Document `old_ucf_list` purpose
  - Check: Is it used anywhere?
  - If not: Consider removing

**Tests needed**: 4-5 unit tests

---

### Phase 3: Improve (2-3 hours)

**Priority**: 🟠 When time permits

- [ ] Make `clean_up_place_ucf_list` transactional
  - Add: Atomic counter updates
  
- [ ] Enhance rake task to fix type mismatches
  - Change: from detecting only to fixing included
  
- [ ] Fix `SearchRecord#contains_wildcard_ucf?` return type
  - Add: Explicit boolean conversion `!!ucf_name`

**Tests needed**: 5-6 unit tests

---

## 📞 Quick Troubleshooting

| Problem | Location | Fix |
|---------|----------|-----|
| Entry edit fails with NoMethodError | `entry.update_place_ucf_list` | Add null guard for search_record |
| Counters out of sync | `entry.update_and_save` | Recalculate place.ucf_list_record_count |
| Place corrupted after file delete | `file.clean_up_place_ucf_list` | Make atomic with counters |
| Stale entries after file replace | `rake ucf:validate_ucf_lists` | Run task with `fix` flag |
| Test fails `Hash#include?` | `entry.handle_add_ucf` | Type is {} not [], fix Place#update_ucf_list |

---

## 🎯 Key Principles

1. **Type Consistency**: All values in `place.ucf_list` MUST be Arrays
2. **Null Safety**: Always check existence before method calls
3. **Atomicity**: Both models persist or neither (rollback)
4. **Accuracy**: Counters must reflect actual state
5. **Idempotency**: Operations safe to retry

---

## ⚡ Performance & Maintenance Quick Tips

### Quick Wins (Easy Implementation)

1. **Add MongoDB Index** (30 min)
   ```ruby
   # app/models/place.rb
   index({ ucf_list: 1 }, { sparse: true, background: true })
   ```
   Impact: 50-100x faster queries

2. **Add Guard Clauses** (30 min)
   ```ruby
   return if destroyed? || file.destroyed? || place.destroyed?
   ```
   Impact: Prevents crashes

3. **Transactional Cleanup** (1 hour)
   Replace fetch-then-update with single atomic update  
   Impact: Eliminates race condition

### Medium-Effort Improvements (High Impact)

4. **Incremental Counter Updates** (1.5 hours)
   - Replace O(N) recalculation with O(1) operations
   - Impact: 95% faster counter updates

5. **Batch Place Updates** (2-3 hours)
   - Accumulate changes, single save per file
   - Impact: 60% fewer database writes

6. **Wildcard Scan Caching** (1 hour)
   - Cache results for 5 minutes
   - Impact: 90% fewer redundant scans

7. **Optimized Rake Task** (2 hours)
   - Use aggregation pipeline instead of loops
   - Impact: 99% faster orphan detection

### Implementation Priority

**Phase A (Critical)**: #1, #2, #3 (3 hours) → Fixes bugs + quick wins  
**Phase B (Recommended)**: #4, #5, #6 (5 hours) → Major performance boost  
**Phase C (Optional)**: #7 (2 hours) → Maintenance efficiency

---

## 📚 Related Documentation

- [UCF_LOGIC_REVIEW.md](UCF_LOGIC_REVIEW.md) — Detailed analysis + 8 recommendations with code
- [UCF_IMPLEMENTATION_GUIDE.md](UCF_IMPLEMENTATION_GUIDE.md) — Complete Phase 1-4 implementation guide
- [UCF_SCENARIO_ANALYSIS.md](UCF_SCENARIO_ANALYSIS.md) — State diagrams and workflows

---

## ✅ Checklist Before Code Review

- [ ] Type consistency verified (all Arrays)
- [ ] Null guards added
- [ ] Error handling symmetric
- [ ] Counters recalculated
- [ ] Tests added for new behavior
- [ ] Existing tests still pass
- [ ] No new compiler warnings
- [ ] RuboCop violations addressed
- [ ] Code commented if non-obvious
- [ ] Documentation updated

---

**Last Updated**: February 12, 2026  
**Status**: Ready for Phase 1 implementation  
**Contact**: Development Team
