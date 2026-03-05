# Deduplication Implementation Guide

**Date**: March 4, 2026  
**Status**: Ready for Implementation  
**File**: `/app/models/search_query.rb`

---

## The Fix

### Location
- **Method**: `get_and_sort_results_for_display`
- **Line**: After line 686 (after Step 7 comment)
- **Scope**: Add Step 7.5 to deduplicate results

### Current Code (Lines 682-692)

```ruby
    # Step 7: Handle UCF results safely
    ucf_results = self.ucf_results.presence || []
    # Rails.logger.info { "[GetSortDisplay] ---Step 7: UCF results (#{ucf_results.size})\n#{ucf_results.ai(index: true, plain: true)}" }

    # Step 8: Wrap results in SearchRecord objects
    wrapped_results = search_results.map { |h| SearchRecord.new(h) }
    # Rails.logger.info { "[GetSortDisplay] ---Step 8: Wrapped results into SearchRecord objects\n#{wrapped_results.ai(index: true, plain: true)}" }

    # Final return
    response = true
    return response, wrapped_results, ucf_results, result_count
```

### Fixed Code

```ruby
    # Step 7: Handle UCF results safely
    ucf_results = self.ucf_results.presence || []
    # Rails.logger.info { "[GetSortDisplay] ---Step 7: UCF results (#{ucf_results.size})\n#{ucf_results.ai(index: true, plain: true)}" }

    # Step 8: Wrap results in SearchRecord objects
    wrapped_results = search_results.map { |h| SearchRecord.new(h) }
    # Rails.logger.info { "[GetSortDisplay] ---Step 8: Wrapped results into SearchRecord objects\n#{wrapped_results.ai(index: true, plain: true)}" }

    # Step 8.5: Deduplicate — remove UCF results that are already in normal results
    search_result_ids = wrapped_results.map(&:id).to_set
    ucf_results = ucf_results.reject { |record| search_result_ids.include?(record.id) }
    # Rails.logger.info { "[GetSortDisplay] ---Step 8.5: After deduplication (#{ucf_results.size})\n#{ucf_results.ai(index: true, plain: true)}" }

    # Final return
    response = true
    return response, wrapped_results, ucf_results, result_count
```

### What Changed
- Added 3 lines of code (lines after Step 8 comment)
- Creates Set of normal result IDs for O(1) lookup
- Filters UCF results to exclude records already in normal results
- Added optional debug logging (commented out)

---

## Code Explanation

### Line 1: Build ID Set
```ruby
search_result_ids = wrapped_results.map(&:id).to_set
```

**Purpose**: Create a Set of all record IDs in normal results  
**Why Set**: O(1) lookup time vs array O(n)  
**Example**:
```ruby
wrapped_results = [
  SearchRecord(id: "abc123", ...),
  SearchRecord(id: "def456", ...)
]
search_result_ids = {"abc123", "def456"}
```

### Line 2: Filter Duplicates
```ruby
ucf_results = ucf_results.reject { |record| search_result_ids.include?(record.id) }
```

**Purpose**: Keep only UCF results that aren't in the ID set  
**How it Works**:
- Iterates through ucf_results
- Checks if each record's ID is in search_result_ids
- Rejects (removes) records where ID is found
- Returns new array with only unique records

**Example**:
```ruby
ucf_results = [
  SearchRecord(id: "abc123", ...),  # Will be rejected
  SearchRecord(id: "xyz789", ...)   # Will be kept
]
search_result_ids = {"abc123", "def456"}

# After rejection:
ucf_results = [
  SearchRecord(id: "xyz789", ...)   # Kept (not in search_result_ids)
]
```

### Line 3: Debug Logging (Optional)
```ruby
# Rails.logger.info { "[GetSortDisplay] ---Step 8.5: After deduplication (#{ucf_results.size})\n#{ucf_results.ai(index: true, plain: true)}" }
```

**Purpose**: Track deduplication in logs if enabled  
**Currently**: Commented out to reduce log noise  
**When to uncomment**: During debugging duplicate issues

---

## Detailed Walkthrough: Scenario 5

### Initial State
```ruby
search_results = [
  {_id: "grace-123", forename: "grace", surname: "hal{1,2}", ...}
]
```

### Step 8: Wrap Results
```ruby
wrapped_results = [
  SearchRecord(id: "grace-123", forename: "grace", surname: "hal{1,2}", ...)
]
```

### Step 7: Get UCF Results
```ruby
# search_result.ucf_records = ["grace-123"]  (stored in DB)
ucf_results = SearchRecord.find(["grace-123"])
# → ucf_results = [SearchRecord(id: "grace-123", ...)]
```

### Step 8.5: Deduplication
```ruby
# Before
wrapped_results = [SearchRecord(id: "grace-123", ...)]
ucf_results = [SearchRecord(id: "grace-123", ...)]

# Deduplication
search_result_ids = wrapped_results.map(&:id).to_set
# → search_result_ids = {"grace-123"}

ucf_results = ucf_results.reject { |record| search_result_ids.include?(record.id) }
# → check record.id = "grace-123": IS in search_result_ids? YES → reject it
# → ucf_results = []

# After
wrapped_results = [SearchRecord(id: "grace-123", ...)]
ucf_results = []  # ✓ Duplicate removed!
```

### Final Result
```ruby
@search_results = [grace hal{1,2}]  # One appearance
@ucf_results = []                     # Not duplicated
```

---

## Safety & Error Handling

### Safe on Nil?
```ruby
ucf_results = self.ucf_results.presence || []
# Already returns empty array, never nil
# reject on empty array is safe
```

### Safe on Empty wrapped_results?
```ruby
search_result_ids = wrapped_results.map(&:id).to_set
# To_set on empty array returns empty set: Set[]
# reject on empty ucf_results is safe

ucf_results.reject { ... }
# Always returns array, never errors
```

### Safe on Nil IDs?
```ruby
# MongoDB always has _id, never nil for persisted records
# But to be extra safe, could use:
search_result_ids = wrapped_results.compact_map(&:id).to_set
```

---

## Testing the Fix

### Manual Test: Scenario 5

**Setup**:
```ruby
search_query.first_name = "grace"
search_query.can_query_ucf? = true
```

**Before Fix**:
```ruby
response, @search_results, @ucf_results, count = search_query.get_and_sort_results_for_display

@search_results.count     # => 1
@search_results[0].id     # => "grace-123"

@ucf_results.count        # => 1  ❌ DUPLICATE
@ucf_results[0].id        # => "grace-123"  ❌ DUPLICATE
```

**After Fix**:
```ruby
response, @search_results, @ucf_results, count = search_query.get_and_sort_results_for_display

@search_results.count     # => 1
@search_results[0].id     # => "grace-123"

@ucf_results.count        # => 0  ✓ CORRECT
# No @ucf_results[0] because array is empty
```

### RSpec Test Case (Pseudo-code)

```ruby
describe '#get_and_sort_results_for_display' do
  context 'with overlapping normal and UCF results' do
    it 'deduplicates results by removing UCF duplicates' do
      # Setup: Record matches both normal search AND UCF pattern
      record = create(:search_record, 
        forename: "grace",
        surname: "hal{1,2}")
      
      search_query.first_name = "grace"
      
      # Simulate search results
      search_query.search_result.records = {
        record.id => record.attributes
      }
      search_query.search_result.ucf_records = [record.id]
      
      # Execute
      response, search_results, ucf_results, count = 
        search_query.get_and_sort_results_for_display
      
      # Assert
      expect(search_results.map(&:id)).to contain_exactly(record.id)
      expect(ucf_results.map(&:id)).to be_empty
    end
  end
  
  context 'with non-overlapping results' do
    it 'preserves both result sets when no duplicates' do
      # Record A matches normal search only
      record_a = create(:search_record, forename: "grace", surname: "smith")
      # Record B matches UCF pattern only
      record_b = create(:search_record, forename: "john", surname: "hall")
      
      search_query.first_name = "grace"
      
      search_query.search_result.records = {
        record_a.id => record_a.attributes
      }
      search_query.search_result.ucf_records = [record_b.id]
      
      # Execute
      response, search_results, ucf_results, count = 
        search_query.get_and_sort_results_for_display
      
      # Assert
      expect(search_results.map(&:id)).to contain_exactly(record_a.id)
      expect(ucf_results.map(&:id)).to contain_exactly(record_b.id)
    end
  end
end
```

---

## Deployment Checklist

- [ ] Code reviewed and approved
- [ ] Unit tests written and passing
- [ ] Integration tests running
- [ ] Scenarios 4A and 5 tested manually
- [ ] No regressions in other tests
- [ ] Deployed to staging
- [ ] Final smoke testing on staging
- [ ] Ready for production deployment

---

## Rollback Instructions

If issues arise after deployment:

1. **Identify the issue**: Check search results for unexpected behavior
2. **Revert change**: Remove Step 8.5 deduplication code
3. **Redeploy**: Push change to rollback
4. **No data needed**: No database changes, safe to rollback

Rollback code (if needed):
```ruby
# Simply delete these 3 lines:
search_result_ids = wrapped_results.map(&:id).to_set
ucf_results = ucf_results.reject { |record| search_result_ids.include?(record.id) }
# Rails.logger.info { "[GetSortDisplay] ---Step 8.5: After deduplication (#{ucf_results.size})\n#{ucf_results.ai(index: true, plain: true)}" }
```

---

## Performance Analysis

### Time Complexity
- `map(&:id)`: O(n) where n = normal result count
- `to_set`: O(n) 
- `reject { |r| set.include?(r.id) }`: O(m) where m = ucf result count
- **Total**: O(n + m) = linear time

### Space Complexity
- Set of IDs: O(n)
- **Total**: O(n) extra space

### Actual Performance Impact
- **Normal cases**: < 1ms for typical result sets (100-1000 records)
- **Large cases**: Still negligible (milliseconds)
- **Comparison**: Database query execution dominates runtime, not this filtering

### Optimization Note
If performance becomes an issue:
```ruby
# Current: convert to set
search_result_ids = wrapped_results.map(&:id).to_set

# Alternative: keep as array if small result set
search_result_ids = wrapped_results.map(&:id)
# Then use double inclusion if needed:
ucf_results = ucf_results.reject { |r| search_result_ids.include?(r.id) }
```

---

## Success Criteria

After implementing this fix, verify:

1. ✅ Scenario 4A:
   - Search surname "hall"
   - @search_results shows only normal result
   - @ucf_results shows only non-duplicate UCF results

2. ✅ Scenario 5:
   - Search forename "grace"
   - @search_results shows normal result
   - @ucf_results is empty (no duplicate)

3. ✅ Other Scenarios:
   - No regressions in Scenarios 1, 2, 2A, 3, etc.
   - All tests still passing

4. ✅ Edge Cases:
   - Empty result sets handled correctly
   - Multiple records deduplicated properly
   - Performance acceptable

---

## Next Steps

1. Review this implementation guide
2. Update `/app/models/search_query.rb` with Step 8.5
3. Write unit and integration tests
4. Run full test suite
5. Manual testing on Scenarios 4A & 5
6. Code review and approval
7. Deployment to staging
8. Final testing before production

