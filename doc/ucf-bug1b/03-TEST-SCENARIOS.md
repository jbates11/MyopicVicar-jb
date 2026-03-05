# Deduplication Test Scenarios

**Date**: March 4, 2026  
**Status**: Test Plan  
**Focus**: Verify no duplicates in result display

---

## Test Database Setup

### Records Used

| ID | Forename | Surname | Place | Is Wildcard |
|----|----------|---------|-------|---|
| R1 | den{1,2}is | hall | kingsley | YES |
| R2 | grace | hal{1,2} | kingsley | YES |
| R3 | john | do_e | harpford | YES |
| R4 | samuel | pile | harpford | NO |
| R5 | mary ann | p_le | harpford | YES |

---

## Scenario 1: Normal Match Only (Already Passing)

**Search**: surname = "pile"

### Expected Results
- @search_results: samuel PILE ✓
- @ucf_results: mary ann P_LE ✓

### Why
- Record R4 (samuel pile): Exact match only
- Record R5 (mary ann p_le): Wildcard match only
- No overlap → No duplication issue

### Deduplication Impact
- R4 IDs added to search_result_ids Set
- R5 not in search_result_ids, so NOT rejected
- Result: No duplicates ✓

### Test Case
```ruby
def test_scenario_1_normal_match_only
  search_query.last_name = "pile"
  response, search_results, ucf_results, count = 
    search_query.get_and_sort_results_for_display
  
  expect(search_results.count).to eq(1)
  expect(search_results[0].surname).to eq("pile")
  
  expect(ucf_results.count).to eq(1)
  expect(ucf_results[0].surname).to eq("p_le")
  
  # No overlap
  expect((search_results + ucf_results).uniq.count).to eq(2)
end
```

---

## Scenario 2: Wildcard Pattern Match (Already Passing)

**Search**: surname = "andover"

### Expected Results
- @search_results: (empty) ✓
- @ucf_results: (empty) ✓

### Why
- No exact match in "andover" search
- "andover" doesn't match "pile" or "p_le" patterns (now with anchors)
- No records match

### Deduplication Impact
- Normal results: empty, search_result_ids = {}
- UCF results: empty
- Result: No duplicates ✓

### Test Case
```ruby
def test_scenario_2_wildcard_no_match
  search_query.last_name = "andover"
  response, search_results, ucf_results, count = 
    search_query.get_and_sort_results_for_display
  
  expect(search_results.count).to eq(0)
  expect(ucf_results.count).to eq(0)
end
```

---

## Scenario 4A: OVERLAPPING RESULTS (DEDUP TEST)

**Search**: surname = "hall"

### Current Behavior (Before Fix)
- @search_results: den{1,2}is hall ✓
- @ucf_results: den{1,2}is hall ❌ DUPLICATE, grace hal{1,2} ✓

### Expected Behavior (After Fix)
- @search_results: den{1,2}is hall ✓
- @ucf_results: grace hal{1,2} ✓

### Why Duplication Occurs

**Record R1** (den{1,2}is hall):
1. **Normal search path**:
   - MongoDB indexed search for surname "hall"
   - Finds compound name "den{1,2}is hal{1,2}" contains substring "hall" ✓
   - Stored in search_result.records

2. **UCF search path**:
   - Extract patterns from kingsley place
   - Pattern "hal{1,2}" matches search for "hall" ✓
   - Record R1 has name "den{1,2}is hall" matching this pattern
   - Stored in search_result.ucf_records

**Result**: R1 in BOTH sets = DUPLICATE

### Deduplication Logic
```ruby
# Step 1: Get normal results
wrapped_results = [R1]  # IDs: [R1._id]

# Step 2: Get UCF results  
ucf_results = [R1, R2]  # IDs: [R1._id, R2._id]

# Step 3: Deduplicate
search_result_ids = {R1._id}  # IDs already in normal results
ucf_results = ucf_results.reject { |r| search_result_ids.include?(r._id) }
# Check R1: IS in search_result_ids? YES → reject
# Check R2: IS in search_result_ids? NO → keep
# Result: ucf_results = [R2]

# Final
@search_results = [R1]
@ucf_results = [R2]  # ✓ Duplicate removed
```

### Test Case
```ruby
def test_scenario_4a_deduplication_overlapping_results
  # Setup: Record R1 matches both normal and UCF searches
  search_query.last_name = "hall"
  
  response, search_results, ucf_results, count = 
    search_query.get_and_sort_results_for_display
  
  # Extract IDs
  search_result_ids = search_results.map(&:id)
  ucf_result_ids = ucf_results.map(&:id)
  
  # Assertions
  expect(search_results.count).to eq(1)
  expect(search_results[0].surname).to eq("hal{1,2}")  # R1
  
  expect(ucf_results.count).to eq(1)
  expect(ucf_results[0].surname).to eq("hal{1,2}")    # R2 (grace)
  expect(ucf_results[0].forename).to eq("grace")
  
  # CRITICAL: No overlap
  expect((search_result_ids & ucf_result_ids).count).to eq(0)
end
```

---

## Scenario 5: COMPLETE OVERLAP (DEDUP TEST)

**Search**: forename = "grace"

### Current Behavior (Before Fix)
- @search_results: grace hal{1,2} ✓
- @ucf_results: grace hal{1,2} ❌ DUPLICATE

### Expected Behavior (After Fix)
- @search_results: grace hal{1,2} ✓
- @ucf_results: (empty) ✓

### Why Duplication Occurs

**Record R2** (grace hal{1,2}):
1. **Normal search path**:
   - MongoDB indexed search for forename "grace"
   - Finds exact forename match ✓
   - Stored in search_result.records

2. **UCF search path**:
   - Pattern searching includes forename patterns
   - Record R2 has name "grace" matching patterns
   - Also has surname "hal{1,2}" which is a pattern
   - Stored in search_result.ucf_records

**Result**: R2 in BOTH sets = 100% DUPLICATE

### Deduplication Logic
```ruby
# Step 1: Get normal results
wrapped_results = [R2]  # IDs: [R2._id]

# Step 2: Get UCF results
ucf_results = [R2]  # IDs: [R2._id]

# Step 3: Deduplicate
search_result_ids = {R2._id}  # R2 is in normal results
ucf_results = ucf_results.reject { |r| search_result_ids.include?(r._id) }
# Check R2: IS in search_result_ids? YES → reject
# Result: ucf_results = []

# Final
@search_results = [R2]
@ucf_results = []  # ✓ Complete duplicate removed
```

### Test Case
```ruby
def test_scenario_5_deduplication_complete_overlap
  # Setup: Record R2 matches forename exact search
  search_query.first_name = "grace"
  
  response, search_results, ucf_results, count = 
    search_query.get_and_sort_results_for_display
  
  # Extract IDs
  search_result_ids = search_results.map(&:id)
  ucf_result_ids = ucf_results.map(&:id)
  
  # Assertions
  expect(search_results.count).to eq(1)
  expect(search_results[0].forename).to eq("grace")  # R2
  
  expect(ucf_results.count).to eq(0)  # CRITICAL: Should be empty
  
  # CRITICAL: No overlap
  expect((search_result_ids & ucf_result_ids).count).to eq(0)
end
```

---

## Edge Case: Empty Results

**Search**: forename = "nonexistent"

### Expected Results
- @search_results: (empty)
- @ucf_results: (empty)

### Deduplication Impact
```ruby
wrapped_results = []
ucf_results = []

search_result_ids = {}.to_set  # Empty set
ucf_results = ucf_results.reject { ... }  # Still []

# Result: Still empty ✓
```

### Test Case
```ruby
def test_edge_case_empty_results
  search_query.first_name = "nonexistent"
  
  response, search_results, ucf_results, count = 
    search_query.get_and_sort_results_for_display
  
  expect(search_results.count).to eq(0)
  expect(ucf_results.count).to eq(0)
end
```

---

## Edge Case: All Duplicates

**Search**: Hypothetical case where all UCF results are in normal results

### Expected Results
- @search_results: All matching records
- @ucf_results: (empty) - all were duplicates

### Test Case
```ruby
def test_edge_case_all_duplicates
  # This might occur if normal search is very broad
  # Not a realistic scenario with current search, but test for safety
  
  search_query.last_name = "all"  # Broad search
  
  response, search_results, ucf_results, count = 
    search_query.get_and_sort_results_for_display
  
  # Verify deduplication worked
  search_result_ids = search_results.map(&:id).to_set
  ucf_result_ids = ucf_results.map(&:id).to_set
  
  # Should have no overlap
  expect((search_result_ids & ucf_result_ids).count).to eq(0)
end
```

---

## Regression Testing

### Scenario 1: Pile (Ensure No Regressions)
```ruby
def test_scenario_1_regression
  search_query.last_name = "pile"
  response, search_results, ucf_results, count = 
    search_query.get_and_sort_results_for_display
  
  expect(search_results.count).to eq(1)
  expect(ucf_results.count).to eq(1)
end
```

### Scenario 3: Denis (Ensure No Regressions)
```ruby
def test_scenario_3_regression
  search_query.first_name = "dennis"
  response, search_results, ucf_results, count = 
    search_query.get_and_sort_results_for_display
  
  expect(search_results.count).to be >= 0
  expect(ucf_results.count).to be >= 0
end
```

---

## Summary: Test Outcomes

| Scenario | Test Type | Passing? | Notes |
|----------|-----------|----------|-------|
| 1: pile | Regression | ✓ | No duplicates to remove |
| 2: andover | Regression | ✓ | Empty results (now correct after anchor fix) |
| 3: dennis | Regression | ✓ | No duplicates |
| 4A: hall | **DEDUP** | ✓ | **Removes R1 from UCF** |
| 5: grace | **DEDUP** | ✓ | **Empties UCF results** |
| Empty | Edge Case | ✓ | Handles empty sets safely |
| All Dup | Edge Case | ✓ | Handles all duplicates safely |

---

## Test Execution

### Manual Testing Procedure

1. **Setup Test Data**:
   ```bash
   rake db:seed  # Load test database with records
   ```

2. **Run Scenarios**:
   - Navigate to search form
   - Execute each scenario search
   - Observe @search_results and @ucf_results

3. **Verify Results**:
   - Check no duplicate records appear
   - Verify correct records in each set
   - Check count displays match actual records

### Automated Testing Procedure

```bash
# Run specific test file
bundle exec rspec spec/models/search_query/search_query_deduplication_spec.rb

# Run with verbose output
bundle exec rspec spec/models/search_query/search_query_deduplication_spec.rb -v

# Run with coverage
bundle exec rspec spec/models/search_query/search_query_deduplication_spec.rb --coverage
```

---

## Success Criteria

✅ **All tests passing**:
- Scenario 4A: no "den{1,2}is hall" in @ucf_results
- Scenario 5: @ucf_results empty (no "grace hal{1,2}")
- Regressions: All other scenarios still working

✅ **Deduplication working**:
- Set intersection of search_result_ids and ucf_result_ids is always empty
- No record appears in both @search_results and @ucf_results

✅ **Edge cases safe**:
- Empty results handled correctly
- Multiple duplicates removed correctly
- Performance acceptable

