# UCF Deduplication Bug Analysis

**Date**: March 4, 2026  
**Status**: Analysis Complete  
**Issue Type**: Data Duplication in Result Sets

---

## Problem Statement

Records that match BOTH exact search criteria AND UCF wildcard patterns are being displayed in **both** result sets:
- `@search_results` (Normal/Exact matches) 
- `@ucf_results` (Uncertain/Wildcard matches)

This creates duplicate entries in the search results display.

### User-Reported Scenarios

**Scenario 4A**: Search surname = "hall"
- Record: "den{1,2}is hall"
- **Current (Wrong)**:
  - @search_results = den{1,2}is hall ✓
  - @ucf_results = den{1,2}is hall ❌ (duplicate), grace hal{1,2} ✓
- **Expected (Correct)**:
  - @search_results = den{1,2}is hall ✓
  - @ucf_results = grace hal{1,2} ✓ (no duplicates)

**Scenario 5**: Search forename = "grace"
- Record: "grace hal{1,2}"
- **Current (Wrong)**:
  - @search_results = grace hal{1,2} ✓
  - @ucf_results = grace hal{1,2} ❌ (duplicate)
- **Expected (Correct)**:
  - @search_results = grace hal{1,2} ✓
  - @ucf_results = (empty) ✓ (no duplicates)

---

## Why the Duplication Occurs

### How @search_results is Populated

From `SearchQuery#get_and_sort_results_for_display`:

```ruby
# Step 1: Extract normal search results
search_results = self.search_result.records.values.compact
# Returns all records matching the EXACT search criteria
# Example: surname = "hall" matches record {_id: "12345", name: "hall", ...}
```

These are records stored in MongoDB's compound index that matched the exact query.

### How @ucf_results is Populated

From `SearchQuery#get_and_sort_results_for_display`:

```ruby
# Step 7: Extract UCF wildcard results
ucf_results = self.ucf_results.presence || []
```

Which calls `SearchQuery#ucf_results`:

```ruby
def ucf_results
  if self.can_query_ucf?
    ids = self.search_result.ucf_records
    records = SearchRecord.find(ids)  # Fetch by ID
    records
  else
    []
  end
end
```

These are records fetched by fetching records whose IDs are in `search_result.ucf_records`.

### How UCF Records Get Stored

From `SearchQuery#search_ucf`:

```ruby
# After filtering UCF patterns:
search_result.ucf_records = filtered.map(&:id)
```

The `search_result.ucf_records` contains the IDs of ALL records that match any UCF wildcard pattern in the places, filtered by the search criteria.

### The Root Cause

**Key Insight**: A record can legitimately appear in BOTH sets:

```
Record: { _id: "12345", forename: "grace", surname: "hal{1,2}", ...}
        └─ Stored in place with wildcard patterns
        └─ Has compound name: "grace hal{1,2}"

Case 1: Exact Search for forename="grace"
├── Normal query finds: "grace" → record 12345 matches ✓
├── UCF query finds: patterns include "grace" AND surname has "hal{1,2}"
│   └─ Record 12345 matches pattern → stored in UCF records
└── Result: Record 12345 in BOTH sets = DUPLICATE ❌

Case 2: Exact Search for surname="hall"  
├── Normal query finds: "hall" → compound name "grace hal{1,2}" matches
│   └─ MongoDB index search matches this record ✓
├── UCF query finds: surname patterns include "hal{1,2}" which matches "hall"
│   └─ Record matches UCF pattern → stored in UCF records
└── Result: Record in BOTH sets = DUPLICATE ❌
```

---

## Data Flow Diagram

```
SearchQuery#search()
│
├─ Step 1: search_normal()
│  └─ MongoDB query on exact criteria
│     └─ Stores matching IDs in search_result.records
│
├─ Step 7: search_ucf()
│  ├─ Extract UCF patterns from places
│  ├─ Filter against search criteria
│  └─ Stores matching IDs in search_result.ucf_records
│
└─ SearchQuery#get_and_sort_results_for_display()
   │
   ├─ Step 1-6: Build @search_results
   │  ├─ Fetch search_result.records (MongoDB results)
   │  └─ Apply filters: name_types, embargoed, census fields
   │  └─ Result: Array of SearchRecord objects
   │
   ├─ Step 7: Build @ucf_results  
   │  ├─ Fetch search_result.ucf_records (ID list)
   │  └─ SearchRecord.find(ids) → Fetch by ID
   │  └─ Result: Array of SearchRecord objects
   │
   └─ ❌ ISSUE: Both arrays may contain same records!
      └─ Solution: Deduplicate by ID
```

---

## Technical Root Cause

The issue is not in filtering or regex (those work correctly now post-fix). The issue is in **result assembly**.

### Current Flow (Broken)

```ruby
# get_and_sort_results_for_display

# Build normal results (Steps 1-6)
search_results = self.search_result.records.values.compact  # IDs: [12345, 67890]
search_results = filter_name_types(search_results)
# ... more filters ...
wrapped_results = search_results.map { |h| SearchRecord.new(h) }

# Build UCF results (Step 7)
ucf_results = self.ucf_results.presence || []  # IDs: [12345, 99999]
# Note: Both include record 12345!

# Return
return response, wrapped_results, ucf_results, result_count
```

### Problem

- `wrapped_results` contains records with IDs: [12345, 67890]
- `ucf_results` contains records with IDs: [12345, 99999]
- Record 12345 appears in BOTH arrays

---

## Solution Design

### Approach: Deduplication by ID

**Where**: `get_and_sort_results_for_display` method  
**When**: After Step 7 (after getting both result sets)  
**How**: Filter ucf_results to exclude any record whose ID is in wrapped_results

### Implementation Steps

**Step 7.5**: Add deduplication logic

```ruby
# Step 7: Handle UCF results safely
ucf_results = self.ucf_results.presence || []

# Step 7.5: Remove UCF results that are already in normal results
search_result_ids = wrapped_results.map(&:id).to_set
ucf_results = ucf_results.reject { |record| search_result_ids.include?(record.id) }
```

### Why This Works

1. **Preserves normal results**: wrapped_results unchanged
2. **Removes duplicates from UCF**: Filters out records already in normal results
3. **Maintains UCF results**: Keeps non-duplicate UCF matches
4. **Efficient**: Using Set for O(1) lookup instead of O(n)

### Example: Scenario 5 After Fix

```ruby
# Before deduplication
wrapped_results = [grace hal{1,2} (id: 99999), ...]
ucf_results = [grace hal{1,2} (id: 99999), ...]  # DUPLICATE

# After deduplication (Step 7.5)
search_result_ids = {99999, ...}  # IDs already in normal results
ucf_results = ucf_results.reject { |r| search_result_ids.include?(r.id) }
# → ucf_results = []  # Removed duplicate

# Final result
@search_results = [grace hal{1,2}]
@ucf_results = []
```

---

## Edge Cases & Safety

### Edge Case 1: Record in UCF but not normal results
- Record matches UCF pattern
- Doesn't match exact criteria
- **Action**: Keep in ucf_results ✓

### Edge Case 2: Record in both sets
- Records matches both exact criteria and UCF pattern
- **Action**: Keep only in search_results, remove from ucf_results ✓

### Edge Case 3: Empty result sets
- One or both result sets empty
- **Action**: Deduplication still works safely (Set operations on empty arrays are safe) ✓

### Edge Case 4: Performance
- **Concern**: Converting wrapped_results to Set multiple times
- **Solution**: Convert once before the loop ✓

---

## Implementation Verification

###  Test Case: Scenario 4A

**Setup**:
```ruby
# Database record
record_hall = { 
  _id: "r1",
  forename: "den{1,2}is",
  surname: "hal{1,2}",
  place_id: harpford
}

# Search criteria
search = { surname: "hall" }
```

**Current Flow (Broken):**
```ruby
# Normal search finds exact match
search_results = [record_hall]  # ID: r1

# UCF search finds pattern match
ucf_patterns = extract_from place "hal{1,2}" in surnames
filtered_ucf = [record_hall]  # ID: r1, matches pattern and criteria

# Result: DUPLICATE
@search_results = [record_hall]
@ucf_results = [record_hall]  # WRONG
```

**After Fix:**
```ruby
# Same flow, but with deduplication
search_results = [record_hall]  # ID: r1
ucf_results = [record_hall]  # ID: r1, matches pattern

# Deduplication (Step 7.5)
search_result_ids = {r1}
ucf_results = ucf_results.reject { |r| search_result_ids.include?(r.id) }
# → ucf_results = []

# Result: NO DUPLICATE ✓
@search_results = [record_hall]
@ucf_results = []  # CORRECT
```

---

## Files to Modify

| File | Location | Change | Lines |
|------|----------|--------|-------|
| `/app/models/search_query.rb` | Method: `get_and_sort_results_for_display` | Add Step 7.5: deduplication logic | ~5 lines |

---

## Testing Strategy

### Unit Tests
- Test deduplication logic with mock data
- Test edge cases (empty sets, no duplicates, all duplicates)

### Integration Tests
- Scenario 4A: Search "hall" → no duplicates
- Scenario 5: Search "grace" → no duplicates
- Ensure non-duplicate UCF results preserved

### Manual Testing
- Run all 5+ scenarios through search interface
- Verify @search_results and @ucf_results don't overlap

---

## Performance Impact

- **Positive**: Reduces redundant data in memory
- **Neutral**: Set conversion O(n), rejection O(n) = O(n) total
- **Safe**: No additional database queries

---

## Rollback Plan

If issues arise:
1. Remove Step 7.5 deduplication code
2. Redeploy
3. No database changes, safe to rollback

---

## Conclusion

The deduplication issue is a **result assembly problem**, not a search problem. The fix is simple: filter ucf_results to exclude records already in search_results by comparing IDs.

**Fix Complexity**: 🟢 LOW (5 lines of code)  
**Risk Level**: 🟢 LOW (isolated, reversible)  
**Test Coverage**: 🟠 MEDIUM (needs new test cases)

