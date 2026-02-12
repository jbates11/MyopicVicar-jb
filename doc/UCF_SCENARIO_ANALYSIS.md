# UCF Logic - Scenario Analysis & State Diagrams

**Purpose**: Detailed workflow analysis for three UCF scenarios  
**Audience**: Developers and architects  
**Last Updated**: February 12, 2026

---

## Overview: Three Scenarios

```
┌─────────────────────────────────────────────────────────────────┐
│                    UCF SYNCHRONIZATION POINTS                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Scenario 1: CSV FILE UPLOAD (New file)                         │
│  ├─ Trigger: User uploads new CSV batch                         │
│  ├─ Path: NewFreeregCsvUpdateProcessor → Place#update_ucf_list │
│  └─ Both lists populated from scratch                           │
│                                                                   │
│  Scenario 2: CSV FILE REPLACEMENT (Re-upload with changes)      │
│  ├─ Sub-cases:                                                   │
│  │  2.1: Full re-upload (complete replacement, delete old file) │
│  │  2.2: Partial + modified entries (merge mode)                │
│  │  2.3: Partial + new entries (merge mode)                     │
│  │  2.4: Partial + new + modified entries (merge mode)          │
│  ├─ Path: OldFile#clean_up → NewFile#upload OR entry-merge     │
│  └─ Lists updated via deletion (2.1) or incremental (2.2-2.4)  │
│                                                                   │
│  Scenario 3: CSV ENTRY EDIT (Individual record)                 │
│  ├─ Trigger: User edits entry, wildcard status changes          │
│  ├─ Path: Controller → Entry#update_place_ucf_list              │
│  └─ Both lists updated incrementally                            │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Scenario 1: CSV File Upload (New File)

### State Diagram

```
BEFORE UPLOAD:
├─ File: (does not exist)
├─ Place.ucf_list: {}
└─ Place.ucf_list_file_count: 0

                 ↓ (User uploads file → system processes batch)

DURING PROCESSING:
├─ Entries created for all records
├─ SearchRecords generated with names/wildcards
└─ No UCF list updates yet

                 ↓ (Batch processing complete)

IMMEDIATELY AFTER PROCESSING:
├─ File.ucf_list: [] (empty array initially)
├─ Place.ucf_list: {}
└─ update_place_after_processing() called

                 ↓ (Call Place#update_ucf_list(file))

AFTER UPDATE_UCF_LIST:
├─ File.ucf_list: [SR1, SR2, ...]  OR  []
├─ Place.ucf_list: { file_id_str: [SR1, SR2, ...] }  OR  {} (if no records)
├─ Place.ucf_list_file_count: 1  (or 0 if no wildcards)
├─ Place.ucf_list_record_count: N  (or 0 if no wildcards)
├─ File.ucf_updated: today
└─ Place.ucf_list_updated_at: now
```

### Call Sequence

```
1. Upload Handler
   ├─ Creates Freereg1CsvFile record
   ├─ Streams CSV entries
   ├─ Creates Freereg1CsvEntry for each row
   ├─ Validates & checks for errors
   └─ Triggers processing

2. NewFreeregCsvUpdateProcessor#process_the_data()
   ├─ For each location (place):
   │  ├─ setup_batch_for_processing(project, location, file)
   │  │  └─ Creates or retrieves file batch
   │  ├─ process_the_records_for_this_batch_into_the_database()
   │  │  ├─ For each entry:
   │  │     ├─ check_and_create_db_record_for_entry()
   │  │        └─ Creates SearchRecord with names + wildcard flags
   │  │     └─ Tracks success/failure/no-change
   │  ├─ update_the_file_information()
   │  │  └─ Updates error counts, processed flags
   │  └─ ★ update_place_after_processing() 
   │     ├─ Fetches Place by (chapman_code, place_name)
   │     ├─ place.ucf_list[file_id] = []  ← Pre-initialize
   │     ├─ place.save
   │     ├─ place.update_ucf_list(file)   ← Scan for wildcards
   │     ├─ place.save
   │     └─ file.save
   └─ Refreshes place cache if needed

3. File#search_record_ids_with_wildcard_ucf()
   └─ Scans all entries for wildcard SearchRecords
      ├─ For each entry:
      │  ├─ Checks if entry.search_record exists
      │  ├─ Calls search_record.contains_wildcard_ucf?
      │  └─ Collects matching IDs
      └─ Returns array of IDs

4. Place#update_ucf_list(file)
   ├─ Fetches wildcard IDs: ids = file.search_record_ids_with_wildcard_ucf
   ├─ If ids.present?:
   │  ├─ place.ucf_list[file_id] = ids         ← Array of IDs
   │  ├─ file.ucf_list = ids                   ← Array of IDs
   │  └─ Updates counters & timestamps
   └─ File saved, place saved
```

### Code Execution Path

**Controller**: `Freereg1CsvFilesController#create` or similar  
**Service**: `NewFreeregCsvUpdateProcessor#process_the_data()`  
**Key Classes**:
- `Freereg1CsvFile` — File batch
- `Freereg1CsvEntry` — Individual CSV row
- `SearchRecord` — Searchable record with names
- `Place` — Geographic location

**Key Methods**:
```ruby
# NewFreeregCsvUpdateProcessor
update_place_after_processing(file, chapman_code, place_name)

# Place
update_ucf_list(file)

# Freereg1CsvFile
search_record_ids_with_wildcard_ucf()
```

### Final State Example

**Upload: 1 file with 3 entries (2 with wildcards)**

```
PLACE STATE:
{
  _id: ObjectId("..."),
  ucf_list: {
    "<file_id_1>": ["<record_id_1>", "<record_id_2>"]
  },
  ucf_list_file_count: 1,
  ucf_list_record_count: 2,
  ucf_list_updated_at: DateTime(2026-02-12 10:30:00)
}

FILE STATE:
{
  _id: ObjectId("...<file_id_1>..."),
  ucf_list: ["<record_id_1>", "<record_id_2>"],
  ucf_updated: Date(2026-02-12)
}
```

### Common Issues

| Issue | Symptom | Root Cause |
|-------|---------|-----------|
| Empty list stored as `{}` | Entry edit fails with NoMethodError | OLD code sets empty hash instead of array |
| Counters not updated | Stale metrics after entry edit | Entry edit doesn't recalculate places counters |
| Double-save inefficiency | Extra DB writes | Pre-initialization + update both save |

---

## Scenario 2: CSV File Replacement (Re-upload with Changes)

### Overview

**Definition**: User re-uploads file with one of four modification patterns:
- **Case 2.1**: Full replacement (all new entries, delete old file entirely)
- **Case 2.2**: Partial merge with modified entries (some entries changed, rest unchanged)
- **Case 2.3**: Partial merge with new entries only (all original entries intact, new ones added)
- **Case 2.4**: Partial merge with new + modified entries (combination of cases 2.2 and 2.3)

All cases involve **file replacement**, but differ in scope and atomicity.

---

### Case 2.1: Full Re-upload (Complete Replacement)

### State Diagram

```
BEFORE REPLACE:
├─ File (OLD):
│  ├─ ucf_list: [SR1, SR2, ...]
│  └─ belongs to Place (YKS/York)
├─ Place.ucf_list: { old_file_id: [SR1, SR2, ...], other_file: [...] }
└─ Place.ucf_list_file_count: 2

                 ↓ (User initiates file replacement)

REPLACEMENT INITIATED:
├─ User confirms: "Replace batch"
├─ System validates old file can be deleted
│  ├─ Check: not locked
│  ├─ Check: not over 5000 records
│  └─ Check: valid location hierarchy
└─ Proceed with old file removal OR rollback

                 ↓ (Remove old file)

OLD FILE REMOVAL:
├─ Old file#remove_batch()
├─ ★ old_file.clean_up_place_ucf_list()
│  ├─ location_from_file(old_file) → Place
│  ├─ place.ucf_list.delete(old_file_id)
│  ├─ place.save
│  ├─ old_file.ucf_list = []
│  └─ old_file.save
├─ Old file soft-deleted or destroyed
└─ Place relationships updated

STATE AFTER DELETION:
├─ Old File.ucf_list: []
├─ Old File.destroyed: true (or marked inactive)
└─ Place.ucf_list: { other_file: [...] }  ← old_file_id removed

                 ↓ (Upload new file version)

NEW FILE UPLOADED:
├─ Same flow as Scenario 1
├─ New file#create → entries created → SearchRecords generated
├─ ★ update_place_after_processing(new_file, ...)
│  ├─ place.update_ucf_list(new_file)
│  └─ new_file.ucf_list updated
└─ Place.ucf_list: { other_file: [...], new_file_id: [SRx, SRy, ...] }

FINAL STATE:
├─ Old File: destroyed/inactive
├─ New File: active with new UCF list
├─ Place.ucf_list: contains new_file_id (not old_file_id)
└─ Place counters: updated to include only active files
```

### Call Sequence

```
PART A: OLD FILE DELETION
─────────────────────────
1. UI Action: User clicks "Replace Batch"
   └─ Calls `Freereg1CsvFile#remove_batch()`

2. Freereg1CsvFile#remove_batch()
   ├─ Validation checks:
   │  ├─ File size < 5000 records?
   │  ├─ Not locked by transcriber?
   │  └─ Not locked by coordinator?
   ├─ If validation fails:
   │  └─ Return error message
   └─ If valid:
      ├─ add_to_rake_delete_list()
      ├─ save_to_attic()            ← Backup to attic
      ├─ ★ clean_up_place_ucf_list()  ← Remove from place
      ├─ destroy()                   ← Delete file record
      ├─ PhysicalFile.delete_document() ← Clean up physical
      └─ Return success message

3. Freereg1CsvFile#clean_up_place_ucf_list()
   ├─ location_from_file() → (proceed, place, church, register)
   ├─ Guard: proceed && place.present?
   ├─ If true:
   │  ├─ place.ucf_list.delete(file_id)
   │  ├─ place.update(ucf_list: cleaned_list)
   │  └─ file.update(ucf_list: [])
   └─ Else: return early

PART B: NEW FILE UPLOAD
──────────────────────
4. UI Action: User uploads new file
   └─ Same as Scenario 1 (see above)

5. System detects same location:
   ├─ New file: (YKS, York)
   ├─ Place.ucf_list: Now contains only new file ID
   └─ Counters recalculated
```

### State Transition Table

| Point | Old File ID | Old File UCF | Place.ucf_list | Place Count |
|-------|-------------|--------------|-----------------|------------|
| Before replace | present | [SR1, SR2] | {old: [SR1, SR2], other: [...]} | 2 |
| After deletion | destroyed | — | {other: [...]} | 1 |
| After new upload | — | — | {other: [...], new: [SRa, SRb]} | 2 |

### File Lifecycle

```
State Transitions:

UPLOADED (initial)
  ↓
PROCESSED (batches created)
  ↓
ACTIVE (entries searchable)
  ├─→ LOCKED_BY_TRANSCRIBER
  ├─→ LOCKED_BY_COORDINATOR
  ├─→ UNLOCKED
  └─→ READY_FOR_REPLACE
       ↓
     REPLACED:
       ├─ OLD FILE:
       │  ├─ clean_up_place_ucf_list()
       │  ├─ save_to_attic()
       │  └─ destroyed
       └─ NEW FILE: (repeat Scenario 1)
```

### Comparison: Delete vs. Replace

| Operation | Method | UCF Cleanup | File Status |
|-----------|--------|------------|-------------|
| **Delete** | `remove_batch()` | Via `clean_up_place_ucf_list()` | Destroyed |
| **Soft Delete** | Disable flag | Manual cleanup | Marked inactive |
| **Replace** | `remove_batch()` + upload | Sequential cleanup+init | Old destroyed, new created |

### Risk Points

| Risk | Mitigation |
|------|-----------|
| Old file deletion fails mid-way | Transaction wrapper + rollback |
| Place corrupted if deletion partially succeeds | Atomic update with counters |
| New file upload fails after old deletion | Idempotent retry; old file can be recovered from attic |

---

### Case 2.2: Partial Re-upload (With Modified Entries)

```
BEFORE RE-UPLOAD:
├─ File (V1): [E1, E2, E3, E4] entries
│  └─ E2, E3 have wildcards → file.ucf_list = [SR2, SR3]
├─ Place.ucf_list: {file_id: [SR2, SR3]}
└─ Place.ucf_list_file_count: 1, record_count: 2

                 ↓ (User re-uploads file V2 with modifications only)

NEW FILE CONTENTS (V2 - modifications, no new entries):
├─ E1 (unchanged, no wildcard)
├─ E2 (modified: removes wildcard) ← WAS SR2, NOW plain
├─ E3 (modified: adds wildcard) ← WAS plain, NOW SR3'  
└─ E4 (removed from file)

                 ↓ (Processor identifies as update/merge)

PROCESSING LOGIC (per-entry):
├─ Entry E1: No change → Skip UCF update (Case 0)
├─ Entry E2: Wildcard removed → Call update_place_ucf_list() [Case B]
│            place.ucf_list[file_id].delete(SR2)
├─ Entry E3: Wildcard added → Call update_place_ucf_list() [Case A]  
│            place.ucf_list[file_id] << SR3'
└─ Entry E4: Deleted → Freereg1CsvEntry destroyed
             SearchRecord destroyed
             UCF cleanup via before_destroy

                 ↓ (clean_up_unused_batches())

CLEANUP: Remove E4 references
├─ E4 entry destroyed
└─ E4 search_record destroyed

                 ↓ (Final state)

AFTER RE-UPLOAD:
├─ File (V2): [E1, E2 (modified), E3 (modified)]
│  └─ E2 plain, E3 wildcard → file.ucf_list = [SR3'] (was [SR2, SR3])
├─ Place.ucf_list: {file_id: [SR3']}
├─ SearchRecord E2: No wildcards
├─ SearchRecord E3: Wildcard updated
└─ Place counters: record_count=1 (was 2), file_count=1
```

#### Key Characteristics (Case 2.2)

| Aspect | Details |
|---|---|
| **Trigger** | User corrects/modifies existing entries, no new entries |
| **Entry Matching** | By entry_number or ID |
| **Processing** | Merge mode: per-entry update with rollback |
| **Atomicity** | Entry-level atomic (per entry)|  
| **UCF Updates** | Incremental (add/remove as needed) |
| **Rollback** | Per-entry reverse operations |
| **Risk** | Partial failure could orphan deleted entries |

---

### Case 2.3: Partial Re-upload (With New Entries Only)

#### Definition (Case 2.3)

User re-uploads same file with new entries added, all original entries retained unchanged:
- All original entries from V1 present in V2 (no modifications, no deletions)
- New entries added to the file
- No changes to existing wildcard status

#### State Diagram (Case 2.3)

```
BEFORE RE-UPLOAD:
├─ File (V1): [E1, E2, E3] entries
│  └─ E2, E3 have wildcards → file.ucf_list = [SR2, SR3]
├─ Place.ucf_list: {file_id: [SR2, SR3]}
└─ Place.ucf_list_file_count: 1, record_count: 2

                 ↓ (User re-uploads file V2 with new entries)

NEW FILE CONTENTS (V2 - additions only):
├─ E1 (unchanged, no wildcard) — SAME as V1
├─ E2 (unchanged, has wildcard) — SAME as V1
├─ E3 (unchanged, has wildcard) — SAME as V1
├─ E4 (new entry, no wildcard) ← NEW
└─ E5 (new entry, has wildcard) ← NEW

                 ↓ (Processor identifies as update/merge, additions only)

PROCESSING LOGIC (per-entry):
├─ Entry E1: No change → Skip UCF update (Case 0)
├─ Entry E2: No change → Skip UCF update (Case 0)
├─ Entry E3: No change → Skip UCF update (Case 0)
├─ Entry E4: New, no wildcard → Create entry, skip UCF (Case 0)
└─ Entry E5: New, has wildcard → Create entry + SearchRecord
             Call update_place_ucf_list() [Case C]
             place.ucf_list[file_id] << SR5

                 ↓ (clean_up_unused_batches())

CLEANUP: All entries retained (no orphans)
├─ No entries deleted
├─ Only new entries created
└─ Existing entry references untouched

                 ↓ (Final state)

AFTER RE-UPLOAD:
├─ File (V2): [E1, E2, E3, E4 (new), E5 (new)]
│  └─ E2, E3, E5 have wildcards → file.ucf_list = [SR2, SR3, SR5]
├─ Place.ucf_list: {file_id: [SR2, SR3, SR5]} (was [SR2, SR3])
├─ SearchRecord E4: Created (no wildcard)
├─ SearchRecord E5: Created with wildcards
└─ Place counters: record_count=3 (was 2), file_count=1
```

#### Key Characteristics (Case 2.3)

| Aspect | Details |
|---|---|
| **Trigger** | User adds new entries to file; no modifications or deletions |
| **Entry Matching** | Existing entries skipped (Case 0); new entries created |
| **Processing** | Merge mode: only new entries processed |
| **Atomicity** | Entry-level atomic (per entry) |
| **UCF Updates** | Additive only (no removals) |
| **Rollback** | Per-entry insertion reversal |
| **Risk** | Minimal; no data loss risk (only additions) |

---

### Case 2.4: Partial Re-upload (With New + Modified Entries)

#### Definition (Case 2.4)

User re-uploads with both modifications to existing entries AND new entries:
- Some original entries retained unchanged
- Some original entries modified (same entry_number, different data)
- Some entries removed from file
- NEW entries added to the file

This is the **most complex case**, combining aspects of 2.2 and 2.3.

#### State Diagram (Case 2.4)

```
BEFORE RE-UPLOAD:
├─ File (V1): [E1, E2, E3, E4] entries
│  └─ E2, E3 have wildcards → file.ucf_list = [SR2, SR3]
├─ Place.ucf_list: {file_id: [SR2, SR3]}
└─ Place.ucf_list_file_count: 1, record_count: 2

                 ↓ (User re-uploads file V2 with multiple change types)

NEW FILE CONTENTS (V2 - modifications + additions + deletions):
├─ E1 (unchanged, no wildcard) — SAME as V1
├─ E2 (modified: removes wildcard) ← WAS SR2, NOW plain
├─ E3 (unchanged, has wildcard) — SAME as V1
├─ E4 (removed from file) ← NOT IN V2
├─ E5 (new entry, no wildcard) ← NEW
└─ E6 (new entry, has wildcard) ← NEW

                 ↓ (Processor identifies as update/merge with all types)

PROCESSING LOGIC (per-entry):
├─ Entry E1: No change → Skip UCF update (Case 0)
├─ Entry E2: Wildcard removed → Call update_place_ucf_list() [Case B]
│            place.ucf_list[file_id].delete(SR2)
│            file.ucf_list.delete(SR2)
├─ Entry E3: No change → Skip UCF update (Case 0)
├─ Entry E4: Deleted → Freereg1CsvEntry destroyed
│            SearchRecord destroyed
│            UCF cleanup via before_destroy
├─ Entry E5: New, no wildcard → Create entry, skip UCF (Case 0)
└─ Entry E6: New, has wildcard → Create entry + SearchRecord [Case C]
             place.ucf_list[file_id] << SR6
             file.ucf_list << SR6

                 ↓ (clean_up_unused_batches())

CLEANUP: Remove deleted entry
├─ E4 entry destroyed
├─ E4 search_record destroyed
└─ E4 removed from place.ucf_list tracking

                 ↓ (Final state)

AFTER RE-UPLOAD:
├─ File (V2): [E1, E2 (modified), E3, E5 (new), E6 (new)]
│  └─ E3, E6 have wildcards → file.ucf_list = [SR3, SR6]
├─ Place.ucf_list: {file_id: [SR3, SR6]} (was [SR2, SR3])
├─ SearchRecord E2: Updated, no wildcards
├─ SearchRecord E4: Destroyed
├─ SearchRecord E5: Created (no wildcard)
├─ SearchRecord E6: Created with wildcards
└─ Place counters: record_count=2 (was 2), file_count=1
```

#### Key Characteristics (Case 2.4)

| Aspect | Details |
|---|---|
| **Trigger** | User modifies, adds, and/or deletes entries in same file |
| **Entry Matching** | By entry_number: match existing, skip unchanged, delete missing, create new |
| **Processing** | Merge mode: Case A (add), B (remove), C (create), 0 (skip) combined |
| **Atomicity** | Entry-level atomic; deletions deferred via `clean_up_unused_batches()` |
| **UCF Updates** | All cases: incremental add, remove, create |
| **Rollback** | Per-entry reverse + orphan cleanup reversal |
| **Risk** | 🔴 **Highest**: Combination of add/remove/modify risks; orphan cleanup critical |

---

## Entry Matching Logic for All Partial Cases (2.2, 2.3, 2.4)

How does the processor know E2 is "the same entry modified"?

```ruby
# NewFreeregCsvUpdateProcessor#get_batch_locations_and_records_for_existing_file

existing_file = Freereg1CsvFile.where(:file_name => ..., :userid => ...).first
if existing_file.present?
  # Load existing records keyed by entry_number (or unique identifier)
  @all_existing_records = existing_file.freereg1_csv_entries.index_by { |e| e.register_entry_number }
end

# During processing:
data.each do |entry_data|
  existing_record = @all_existing_records[entry_data[:entry_number]]
  
  if existing_record
    # MATCH: Entry exists with same number
    # → Update logic, potentially remove old search_record
    # → Create new search_record if any field changed
  else
    # NO MATCH: New entry
    # → Create new Freereg1CsvEntry + SearchRecord
  end
end

# After processing:
# → clean_up_unused_batches() identifies entries in @all_existing_records
#   but NOT in new file
# → Deletes those orphaned entries
```

### UCF Update Sequence for Partial Re-upload

```ruby
# For each entry in new file:

entry = Freereg1CsvEntry.find_or_create_by(register_entry_number: ...)
old_search_record = entry.search_record  # ← Keep old for comparison
entry.update(new_data)                   # ← Modify entry
entry.reload                              # ← Fresh state

# Always call update_place_ucf_list for potential change detection
# (even if no change, idempotent)
entry.update_place_ucf_list(place, file, old_search_record)
  # Internally:
  # ├─ file_in_place = place.ucf_list.key?(file_id)
  # ├─ has_wildcard = entry.search_record.contains_wildcard_ucf??.present?
  # └─ Dispatch to Case A/B/C/0

entry.save!
file.save!
place.save!
```

### Risks Specific to Partial Re-upload

| Risk | Scenario | Mitigation |
|------|----------|------------|
| Orphaned entries if deletion fails | E4 in old file not removed | Transaction wrapper, atomicity |
| Desynchronization if entry update fails | E2 modified but UCF not updated | `safe_update_ucf!` rollback |
| Stale counters after entry deletion | E4 removed but counters not recalculated | Recalculate after cleanup |
| Lost old search_record before creating new | E2 update overwrites before UCF check | Keep `old_search_record` before mutation |

### Testing Scenarios for Partial Re-upload

```ruby
# Spec: Entry unchanged (no wildcard before, no wildcard after)
# Action: Re-upload E1 with identical data
# Expected: place.ucf_list unchanged, file.ucf_list unchanged, Case 0

# Spec: Entry modified, lost wildcard (has wildcard before, plain after)
# Action: Re-upload E2, remove wildcard from last_name
# Expected: place.ucf_list[file_id].delete(SR2), file.ucf_list.delete(SR2), Case B

# Spec: Entry modified, gained wildcard (plain before, has wildcard after)
# Action: Re-upload E3, add wildcard to first_name
# Expected: place.ucf_list[file_id] << SR3, file.ucf_list << SR3, Case A

# Spec: Entry deleted from new file
# Action: Re-upload without E4
# Expected: clean_up_unused_batches() destroys E4, triggers orphan cleanup

# Spec: New entry with wildcard
# Action: Re-upload with new E5 containing wildcard
# Expected: Create SearchRecord SR5, Case C: place.ucf_list[file_id] = [SR5]

# Spec: Multiple changes, all preserved/updated correctly
# Action: Re-upload with all 5 changes above
# Expected: Final state matches planned end result
```

---

## Scenario 3: CSV Entry Edit (Individual Record Modification)

### State Diagram

```
INITIAL STATE: Entry exists with non-wildcard record
┌─────────────────────────────────────┐
│ Freereg1CsvEntry                     │
│ ├─ id: entry_123                     │
│ ├─ freereg1_csv_file_id: file_999    │
│ ├─ search_record_id: record_SR1      │
│ └─ search_record#search_names:       │
│    └─ {first: "John", last: "Smith"} │ ← NO WILDCARD
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Place.ucf_list                       │
│ {                                    │
│   "file_999": [...]  (if any)        │ ← Might not exist yet
│ }                                    │
└─────────────────────────────────────┘

                 ↓ (User edits entry)

EDIT IN PROGRESS: Add wildcard to last name
┌─────────────────────────────────────┐
│ Form submission:                     │
│ ├─ first_name: "John"                │
│ ├─ last_name: "Sm*th"  ← Wildcard!   │
│ └─ other fields...                   │
└─────────────────────────────────────┘

                 ↓ (Controller validates & saves)

AFTER SAVE: Entry updated, SearchRecord updated
┌─────────────────────────────────────┐
│ Freereg1CsvEntry (after save)        │
│ └─ search_record#search_names:       │
│    └─ {first: "John", last: "Sm*th"} │ ← HAS WILDCARD
└─────────────────────────────────────┘

                 ↓ (Call update_place_ucf_list)

★ DECISION LOGIC: Which case applies?
├─ file_in_place = place.ucf_list.key?(file_id)
├─ has_wildcard = search_record.contains_wildcard_ucf?.present?
│
├─ Case A (yes, yes):     Add record to lists
├─ Case B (yes, no):      Remove record from lists
├─ Case C (no, yes):      Create new file entry
└─ Case 0 (no, no):       No change

EXECUTION DEPENDS ON PRIOR STATE:

PATH 1: File never scanned (file not in place)
┌──────────────────────────────────────────────┐
│ Before: place.ucf_list = {}                   │
│ Has wildcard? YES                             │
│ → CASE C: handle_new_ucf()                    │
│   ├─ place.ucf_list[file_id] = [SR1]          │
│   ├─ file.ucf_list = [SR1]                    │
│   └─ Update timestamps/counters               │
│ After: place.ucf_list = {"file_id": [SR1]}   │
└──────────────────────────────────────────────┘

PATH 2: File scanned with prior NO wildcard records
┌──────────────────────────────────────────────┐
│ Before: place.ucf_list = {"file_id": []}      │
│ Has wildcard? YES                             │
│ → PROBLEM: handle_add() assumes Array value   │
│   place.ucf_list[file_id].include?(...)       │
│   → TypeError if value is Hash instead       │
│   FIX: Ensure Place.ucf_list values are      │
│        ALWAYS Arrays, never Hashes           │
│        Delete empty entry instead of {}      │
└──────────────────────────────────────────────┘

PATH 3: File scanned with existing wildcard records
┌──────────────────────────────────────────────┐
│ Before: place.ucf_list = {"file_id": [SR2]}  │
│ Has wildcard? YES                             │
│ → CASE A: handle_add_ucf()                    │
│   ├─ place.ucf_list[file_id] << SR1           │
│   ├─ file.ucf_list << SR1                     │
│   └─ Update timestamps/counters               │
│ After: place.ucf_list = {"file_id": [SR2, SR1]}
└──────────────────────────────────────────────┘

                 ↓ (Safe update with rollback)

PERSISTENCE: Atomic save or rollback
├─ If file.save! succeeds:
│  └─ place.save! → both committed
├─ If file.save! fails:
│  ├─ Restore: place.ucf_list = original
│  ├─ Restore: file.ucf_list = original
│  ├─ place.save! & file.save! (rollback)
│  └─ Re-raise original exception
└─ If place.save! fails: (same as above)

FINAL STATE: Entry saved, lists synchronized
┌──────────────────────────────────────────────┐
│ Freereg1CsvEntry (persisted)                  │
│ ├─ search_record_id: SR1                      │
│ └─ search_record.search_names: [Sm*th]        │
│                                               │
│ Place.ucf_list (updated)                      │
│ └─ file_999: [SR1] (or [..., SR1])           │
│                                               │
│ File.ucf_list (updated)                       │
│ └─ [SR1] (or [..., SR1])                      │
│                                               │
│ Timestamps (updated)                          │
│ ├─ place.ucf_list_updated_at: now            │
│ ├─ file.ucf_updated: today                    │
│ └─ Counters recalculated                      │
└──────────────────────────────────────────────┘
```

### Decision Matrix

```
╔════════════════════════════════════════════════════════════════╗
║                   ENTRY EDIT DECISION TREE                      ║
╠════════════════════════════════════════════════════════════════╣
║                                                                 ║
║  file_in_place = place.ucf_list.key?(file_id)?                 ║
║  has_ucf = search_record.contains_wildcard_ucf?.present?       ║
║                                                                 ║
║  ┌──────────────────────────────────────────────────────────┐  ║
║  │ CASE A: file IN place && has wildcard  (yes, yes)       │  ║
║  ├──────────────────────────────────────────────────────────┤  ║
║  │ Action: handle_add_ucf()                                 │  ║
║  │ ├─ Skip if record already in list (idempotent)          │  ║
║  │ ├─ clean_old_ids() if migrating from old record         │  ║
║  │ ├─ place.ucf_list[file_id] << search_record.id          │  ║
║  │ ├─ file.ucf_list << search_record.id                    │  ║
║  │ └─ update_and_save()                                     │  ║
║  │                                                          │  ║
║  │ Example:                                                 │  ║
║  │ Before: place.ucf_list[file_id] = [SR2]                │  ║
║  │ After:  place.ucf_list[file_id] = [SR2, SR1]           │  ║
║  └──────────────────────────────────────────────────────────┘  ║
║                                                                 ║
║  ┌──────────────────────────────────────────────────────────┐  ║
║  │ CASE B: file IN place && NO wildcard  (yes, no)         │  ║
║  ├──────────────────────────────────────────────────────────┤  ║
║  │ Action: handle_remove_ucf()                              │  ║
║  │ ├─ clean_old_ids() (always, to remove stale refs)       │  ║
║  │ ├─ place.ucf_list[file_id].delete(search_record.id)     │  ║
║  │ ├─ file.ucf_list.delete(search_record.id)               │  ║
║  │ └─ update_and_save()                                     │  ║
║  │                                                          │  ║
║  │ Example:                                                 │  ║
║  │ Before: place.ucf_list[file_id] = [SR1, SR2]           │  ║
║  │ After:  place.ucf_list[file_id] = [SR2]                │  ║
║  └──────────────────────────────────────────────────────────┘  ║
║                                                                 ║
║  ┌──────────────────────────────────────────────────────────┐  ║
║  │ CASE C: file NOT in place && has wildcard  (no, yes)   │  ║
║  ├──────────────────────────────────────────────────────────┤  ║
║  │ Action: handle_new_ucf()                                 │  ║
║  │ ├─ place.ucf_list[file_id] = [search_record.id]        │  ║
║  │ ├─ file.ucf_list = [search_record.id] (or append)      │  ║
║  │ └─ update_and_save()                                     │  ║
║  │                                                          │  ║
║  │ Example:                                                 │  ║
║  │ Before: place.ucf_list = {}                             │  ║
║  │ After:  place.ucf_list = {"file_id": [SR1]}             │  ║
║  └──────────────────────────────────────────────────────────┘  ║
║                                                                 ║
║  ┌──────────────────────────────────────────────────────────┐  ║
║  │ CASE 0: file NOT in place && NO wildcard  (no, no)      │  ║
║  ├──────────────────────────────────────────────────────────┤  ║
║  │ Action: NONE (return early)                              │  ║
║  │                                                          │  ║
║  │ Example:                                                 │  ║
║  │ Before: place.ucf_list = {}                             │  ║
║  │ After:  place.ucf_list = {}  (unchanged)                │  ║
║  └──────────────────────────────────────────────────────────┘  ║
║                                                                 ║
╚════════════════════════════════════════════════════════════════╝
```

### Controller Integration

**File**: [app/controllers/freereg1_csv_entries_controller.rb](app/controllers/freereg1_csv_entries_controller.rb#L370)

```ruby
# UPDATE ACTION (Lines ~370-400)
def update
  # ... validation, authorization ...

  # 1. Save entry changes
  @freereg1_csv_entry.update(entry_params)

  # 2. Reload to get fresh search_record
  @freereg1_csv_entry.reload

  # 3. Determine location hierarchy
  _, place, church, register = @freereg1_csv_entry.location_from_entry

  # 4. Update file statistics
  update_file_statistics(place)

  # 5. ★ UPDATE PLACE UCF LIST ← THIS IS SCENARIO 3
  old_search_record = ... # (retrieve if migrating)
  @freereg1_csv_entry.update_place_ucf_list(place, @freereg1_csv_file, old_search_record)

  # 6. Update other stats
  update_other_statistics(place, church, register)

  # 7. Redirect
  redirect_to freereg1_csv_entry_path(@freereg1_csv_entry)
end
```

### Handler Functions

```ruby
# app/models/freereg1_csv_entry.rb

def handle_add_ucf(place, file, file_key, old_search_record)
  # Idempotency guard
  return if place.ucf_list[file_key].include?(search_record.id.to_s)

  # Cleanup old refs if migrating from different entry
  cleanup_old_ids(place, file, file_key, old_search_record)

  # Add new record
  place.ucf_list[file_key] << search_record.id
  file.ucf_list ||= []
  file.ucf_list << search_record.id

  # Persist
  update_and_save(file, place, "Case A: Added UCF record")
end

def handle_remove_ucf(place, file, file_key, old_search_record)
  # Cleanup refs (usually self-removal)
  cleanup_old_ids(place, file, file_key, old_search_record)

  # Remove current record
  place.ucf_list[file_key].delete(search_record.id.to_s)
  file.ucf_list ||= []
  file.ucf_list&.delete(search_record.id.to_s)

  # Persist
  update_and_save(file, place, "Case B: Removed UCF record")
end

def handle_new_ucf(place, file, file_key)
  # Create new file entry
  place.ucf_list[file_key] = [search_record.id]
  file.ucf_list ||= []
  file.ucf_list << search_record.id

  # Persist
  update_and_save(file, place, "Case C: Created new UCF list")
end

def cleanup_old_ids(place, file, file_key, old_search_record)
  # Remove references to previous record if migrating
  return unless old_search_record.present?

  place.ucf_list[file_key].delete(old_search_record.id.to_s)
  file.ucf_list&.delete(old_search_record.id.to_s)

  Rails.logger.info { "---   cleanup_old_ids removed #{old_search_record.id}" }
end

def update_and_save(file, place, message)
  # [THIS IS WHERE COUNTERS SHOULD BE UPDATED - CURRENTLY MISSING]
  file.ucf_updated = Date.today
  file.save
  place.save

  Rails.logger.info { "---✔ #{message} - updated place ucf_list" }
end
```

### State Persistence & Rollback

```ruby
def safe_update_ucf!(place, file)
  # --- SAVE POINT ---
  original_place_list = place.ucf_list.deep_dup
  original_file_list  = file.ucf_list&.dup || []

  begin
    # --- MUTATION (yields to handler) ---
    yield

    # --- COMMIT POINT ---
    file.ucf_updated = Date.today
    file.save!   # Raises on error
    place.save!  # Raises on error
    # ✓ Both persisted, transaction complete

  rescue StandardError => e
    # --- ROLLBACK DECISION ---
    Rails.logger.error("safe_update_ucf! rollback triggered: #{e.message}")

    # Restore from save point
    place.ucf_list = original_place_list
    file.ucf_list  = original_file_list

    # Persist rollback
    begin
      file.save!
      place.save!
      # ✓ Rollback complete
    rescue => rollback_error
      Rails.logger.fatal("Rollback FAILED: #{rollback_error.message}")
      raise rollback_error  # Corrupted state!
    end

    raise e  # Original exception
  end
end
```

### Failure Scenarios

| Scenario | File State | Place State | Recovery |
|----------|-----------|------------|----------|
| File save fails (mutation) | New data in memory | New data in memory | Rollback: restore both from save point |
| Place save fails after file ok | Persisted | New data in memory | Rollback: restore place from save point |
| Both saved successfully | Persisted | Persisted | ✓ Complete, no recovery needed |
| Rollback save fails | ??? | ??? | CORRUPTION: requires manual intervention |

### Monitoring & Auditing

```
Each entry edit should log:

✓ Entry ID
✓ Old state (has_wildcard: before)
✓ New state (has_wildcard: after)
✓ Case applied (A, B, C, or 0)
✓ Place ID updated
✓ File ID updated
✓ Old Record IDs count
✓ New Record IDs count
✓ Timestamp

Example log entry:
[UCF: Entry Edit] entry_id=E123 | state: no_ucf→has_ucf | case=C | 
                  place_id=P456 | file_id=F789 | old_count=0 | new_count=1
```

---

## Summary Comparison Table

| Aspect | Scenario 1: Upload | Scenario 2: File Replacement | Scenario 3: Entry Edit |
|--------|---|---|---|
| **Trigger** | User uploads new file | User replaces existing file | User edits entry |
| **Entry Point** | File parser | UI or merge processor | Controller → update() |
| **Cases** | Single case (new) | 2.1 (full), 2.2 (partial+mod), 2.3 (partial+new), 2.4 (partial combo) | Single case (edit) |
| **Entry Matching** | All new | Case 2.1: none; 2.2-2.4: by entry_number | Single entry |
| **Initial State** | File doesn't exist | File exists; may have entries | File & entry exist |
| **Processing** | Bulk insert all entries | 2.1: delete old + insert new; 2.2-2.4: per-entry merge | Single entry update |
| **Scope** | All new entries | Case 2.1: all; 2.2-2.4: only changed entries | Single entry/record |
| **Type of Update** | Bulk insert | 2.1: delete+insert; 2.2-2.4: add+remove+update | Incremental mutation |
| **Atomicity** | File-level (all or nothing) | 2.1: two-phase operations; 2.2-2.4: per-entry atomic | Single transaction |
| **Idempotent** | ✓ (re-upload = rescan) | ✓ (all cases safe to retry) | ✓ (re-edit = same result) |
| **Rollback** | Via file destruction | 2.1: attic recovery; 2.2-2.4: entry-level reversal | Via save!/rollback |
| **Key Risk** | Type mismatch (Hash vs Array) | 2.1: partial delete; 2.2-2.4: orphan entries | Null search_record |

---

## Recommended Testing Strategy

### Unit Tests Per Scenario

**Scenario 1: Upload**
```ruby
✓ File with 0 wildcards → place.ucf_list empty, file_count = 0
✓ File with N wildcards → place.ucf_list[file_id] has N IDs, file_count = 1
✓ Multiple files same place → ucf_list has multiple keys, file_count = N
✓ Timestamps updated correctly
```

**Scenario 2.1: Full File Replacement**
```ruby
✓ Old file cleanup removes file_id from place
✓ Old file cleanup clears file.ucf_list
✓ Old SearchRecords destroyed
✓ New file upload creates fresh entry
✓ New file has correct wildcards
✓ Place counters final state correct
✓ No orphaned records remain
```

**Scenario 2.2: Partial with Modifications**
```ruby
✓ Unchanged entry (Case 0) — no UCF change
✓ Modified entry loses wildcard (Case B) — remove from place.ucf_list
✓ Modified entry gains wildcard (Case A) — add to place.ucf_list
✓ Deleted entry cleanup removes from place.ucf_list
✓ Counters recalculated after all changes
✓ File.ucf_list updated to reflect surviving wildcards
```

**Scenario 2.3: Partial with New Entries**
```ruby
✓ Original entries untouched (all Case 0)
✓ New entry without wildcard created (Case 0)
✓ New entry with wildcard added to place.ucf_list (Case C)
✓ File.ucf_list includes new wildcard IDs
✓ No cleanup phase (no deletions)
✓ Counters incremented, not recalculated
```

**Scenario 2.4: Partial with Modifications + New Entries**
```ruby
✓ Combination of 2.2 and 2.3 behaviors
✓ Modified entries (Cases A/B/0)
✓ New entries (Cases C/0)
✓ Deleted entries cleanup
✓ Final counters correct (sum of survivors + new)
✓ Orphans properly removed
```

**Scenario 3: Entry Edit**
```ruby
✓ Add wildcard to non-wildcard entry (Case C)
✓ Add wildcard when file already tracked (Case A)
✓ Remove wildcard from wildcard entry (Case B)
✓ No-op when no change (Case 0)
✓ Rollback on save failure
✓ Counters updated
✓ Null search_record handled (guard clause)
```

### Integration Tests
```ruby
✓ Upload + edit + view
✓ Upload + replace + verify old gone
✓ Edit + re-upload + state consistent
✓ Concurrent edits (if applicable)
```

---

## Key Takeaways

### Critical for Developers

1. **Three distinct code paths** — Know which scenario you're in
2. **Type consistency matters** — Always Array, never Hash
3. **Null guards essential** — Search record can be deleted
4. **Counters must sync** — Entry edits need recalculation
5. **Rollback is atomic** — Both models or neither

### For Code Review

- Verify type consistency (Array values only)
- Check guard clauses early
- Ensure error handling is symmetric
- Validate counter recalculation
- Test edge cases (null, empty, concurrent)

---
