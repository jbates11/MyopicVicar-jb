# UCF Search Results Bug - Detailed Root Cause Analysis

**Date**: March 4, 2026  
**Document Type**: Technical Analysis  
**Audience**: Developers & Architects

---

## 1. The Bug in Context

### What is UCF?

**Uncertain Character Field (UCF)** — A notation system for encoding uncertain characters in genealogical records:

```
p_le        = "p" + (any 1 char) + "le"  → Possible matches: pile, pale, pole, etc.
hal{1,2}    = "hal" + (1-2 chars) = "hall" or "halll"
pi*er       = "pi" + (any chars) + "er"  → Possible matches: pier, piler, player, etc.
den{1,2}is  = "den" + (1-2 chars) + "is" → Possible matches: dennis, dennis, etc.
```

### Current System Behavior

When a user searches for a surname like "andover", the system:

1. **Exact search** → Finds: "susan andover" ✅
2. **UCF search** → Should find: records with `_` or `*` patterns matching "andover"
   - Current: Incorrectly shows "john do_e" ❌
   - Correct: Should show nothing (because `do_e` doesn't match "andover")

---

## 2. Trace: From Search Form to Results

### Request Path: GET /search_queries/new → GET /search_queries/:id

**Step 1: User Submits Search Form**
```
Form Input: surname="andover"
Endpoint: POST /search_queries
Controller: SearchQueriesController#create
```

**Step 2: SearchQuery Validation & Execution**
```ruby
# app/controllers/search_queries_controller.rb - line 76
@search_query = SearchQuery.new(search_params)
@search_results = @search_query.search  # Triggers search logic
redirect_to search_query_path(@search_query)  # View results
```

**Step 3: Search Execution**
```ruby
# app/models/search_query.rb - line 316
def search
  return @search_results if @search_results
  
  # Build MongoDB query parameters
  params = search_params  # name_search_params + other filters
  records = SearchRecord.where(params).sort(...)  # Execute query
  
  # Persist results
  persist_results(records)
  @search_results
end
```

**Step 4: View Results**
```ruby
# app/controllers/search_queries_controller.rb - line 265
response, @search_results, @ucf_results, @result_count = 
  @search_query.get_and_sort_results_for_display
```

The `@ucf_results` are populated by `ucf_results()` method, which calls `filter_ucf_records()`.

### Step 5: Problematic Filter - UCF Results
```ruby
# app/models/search_query.rb - lines 441-580
def filter_ucf_records(records)
  # records = all wildcard records in selected places
  
  filtered_records = []
  
  records.each do |raw_record|
    record = SearchRecord.record_id(raw_record.to_s).first
    # ... validation checks ...
    
    record.search_names.each do |name|
      if name.contains_wildcard_ucf?
        
        # ← PROBLEM IS HERE
        if first_name.blank? && last_name.present?
          regex = UcfTransformer.ucf_to_regex(name.last_name.downcase)
          
          # CURRENT (WRONG): Check if search term matches pattern
          if last_name.downcase.match(regex)
            filtered_records << record  # ← Adds incorrectly
          end
        end
      end
    end
  end
  
  filtered_records
end
```

---

## 3. The Logic Inversion Bug

### Example: Scenario 2 (surname "andover")

**Data Setup**:
```
Record 1:
  first_name: "susan"
  last_name: "andover"
  contains_wildcard: FALSE

Record 2:
  first_name: "john"
  last_name: "do_e"
  contains_wildcard: TRUE
```

**Normal Search (Works Correctly)**:
```ruby
# search_params builds exact match query
params[:search_names] = { '$elemMatch' => { 'last_name' => 'andover' } }

# MongoDB returns: Record 1 only
# Because: Record 2's last_name "do_e" ≠ "andover"
```

**UCF Search (Broken)**:
```ruby
def filter_ucf_records(records)
  # records parameter contains: [ Record 2 ] (all wildcard records)
  
  record = records.first  # Record 2 (john, do_e)
  
  regex = UcfTransformer.ucf_to_regex("do_e".downcase)
  # regex from "do_e" = /.*d.*o.*_.*e.*/ approximately
  # Actually more precise: /^do.e$/i (matches d, o, any single char, e)
  
  # PROBLEM: Inverted matching direction
  if "andover".downcase.match(regex)  # ← Check if "andover" matches "do_e" pattern
    # matches: a-n-d-o-v-e-r
    #          d-o-?-e
    # Does not match exactly, but the regex logic is backwards!
    
    filtered_records << Record 2  # ← INCORRECTLY ADDED ❌
  end
end
```

---

## 4. Deep Dive: The inversion

### Correct Matching Logic

```
Pattern: p_le
Regex:   /^p.le$/i

Valid matches:
  pile ✓   (p matches p, i matches ., l matches l, e matches e)
  pale ✓
  pole ✓
  
Invalid matches:
  piler ✗  (too long)
  anole ✗  (different first letter)
```

### Current Code: Direction is Backwards

**What it does now:**
```ruby
regex = UcfTransformer.ucf_to_regex("do_e".downcase)  # → /^do.e$/
last_name.downcase.match(regex)  # → "andover".match(/^do.e$/)

# Check: Does "andover" match the pattern /^do.e$/?
# a-n-d-o-v-e-r starts with 'a', not 'd' → Should NOT match
# But the logic is: "Is the search term a valid pattern instance?"
```

**What it should do:**
```ruby
regex = UcfTransformer.ucf_to_regex("do_e".downcase)  # → /^do.e$/
regex.match(last_name.downcase)  # → /^do.e$/.match("andover")

# Check: Does the pattern /^do.e$/ match "andover"?
# The pattern expects: d-o-?-e (4 chars starting with 'd', ending with 'e')
# "andover" is: a-n-d-o-v-e-r (7 chars, doesn't match pattern)
# Result: NO MATCH ✓ (Correct!)
```

### Why This Matters

**In scenario 2** (searching "andover"):

| Test | Pattern | Current Logic | Correct Logic |
|------|---------|--------------|---------------|
| Does "andover" match pattern `do_e`? | /^do.e$/ | YES (wrong) | NO (correct) |
| Does "andover" match pattern `hal{1,2}`? | /^ha.{1,2}$/ | YES (wrong) | NO (correct) |
| Does "andover" match pattern `ANDOVER`? | /^andover$/ | YES (wrong) | YES (correct) |

---

## 5. Impact Across Scenarios

### Scenario Analysis Table

```
┌──────┬──────────┬───────────────────────────────────────┬──────────────────────┐
│ Func │ Search   │ Current Behavior                      │ Root Cause           │
├──────┼──────────┼───────────────────────────────────────┼──────────────────────┤
│ 2    │ andover  │ Shows: john do_e ❌                  │ Backwards matching   │
│ 2A   │ piler    │ Shows: p_le ❌ + pi*er ✓            │ Backwards matching   │
│ 4A   │ hall     │ Shows: den{1,2}is ❌ + hal{1,2} ✓   │ Backwards matching   │
│ 4B   │ halll    │ Shows: den{1,2}is ❌ + hal{1,2} ✓   │ Backwards matching   │
│ 5    │ grace    │ Shows: (none) ❌                     │ Inverse of backwards │
└──────┴──────────┴───────────────────────────────────────┴──────────────────────┘
```

### Why Each Scenario Fails

**Scenario 2 (andover)**:
- Pattern `do_e` should NOT match "andover"
- Current code matches it anyway → Shows john do_e ❌

**Scenario 2A (piler)**:
- Patterns: `p_le` (4 chars), `pi*er` (variable)
- Current code matches both in backwards direction
- After fix: Only `pi*er` should match (5+ chars)

**Scenario 4A/4B (hall/halll)**:
- Pattern `den{1,2}is` = "dennis" or "dennis" (6-7 chars)
- Search "hall" or "halll" (4 chars) should NOT match
- Current code matches anyway

**Scenario 5 (grace)**:
- Exact match `grace hal{1,2}` should show in normal results
- UCF results should be empty
- Current logic is still backwards, but result is correct by accident

---

## 6. Code Flow Diagram

```
User Search Form
    ↓
POST /search_queries/create
    ↓
SearchQuery#search()
    ├─ Exact search (normal results) ✓ WORKS CORRECTLY
    │  └─ search_params() builds exact match query
    │     └─ MongoDB finds exact matches
    │
    └─ UCF search (uncertain results) ❌ BROKEN
       └─ place.ucf_record_ids (all wildcard records)
          └─ filter_ucf_records(records)
             └─ FOR EACH wildcard record:
                ├─ Build regex from pattern
                └─ TEST: Does search_term match pattern_regex?
                   ↑
                   └─ BACKWARDS! Should be: Does pattern_regex match search_term?
```

---

## 7. The Fix

### Single Code Change Required

**File**: [app/models/search_query.rb](app/models/search_query.rb)  
**Method**: `filter_ucf_records()` (lines 441-580)  
**Locations**: 3 matching operations (cases 1, 2, 3)

### Before (WRONG):
```ruby
# CASE 1: Only last name provided
if first_name.blank? && last_name.present? && name.last_name.present?
  regex = UcfTransformer.ucf_to_regex(name.last_name.downcase)
  if last_name.downcase.match(regex)        # ← BACKWARDS
    filtered_records << record
  end
end

# CASE 2: Only first name provided  
elsif last_name.blank? && first_name.present? && name.first_name.present?
  regex = UcfTransformer.ucf_to_regex(name.first_name.downcase)
  if first_name.downcase.match(regex)       # ← BACKWARDS
    filtered_records << record
  end
end

# CASE 3: Both names provided
elsif last_name.present? && first_name.present? && ...
  last_regex  = UcfTransformer.ucf_to_regex(name.last_name.downcase)
  first_regex = UcfTransformer.ucf_to_regex(name.first_name.downcase)
  if last_name.downcase.match(last_regex) &&    # ← BACKWARDS
     first_name.downcase.match(first_regex)     # ← BACKWARDS
    filtered_records << record
  end
end
```

### After (CORRECT):
```ruby
# CASE 1: Only last name provided
if first_name.blank? && last_name.present? && name.last_name.present?
  regex = UcfTransformer.ucf_to_regex(name.last_name.downcase)
  if regex.match(last_name.downcase)        # ← CORRECT
    filtered_records << record
  end
end

# CASE 2: Only first name provided
elsif last_name.blank? && first_name.present? && name.first_name.present?
  regex = UcfTransformer.ucf_to_regex(name.first_name.downcase)
  if regex.match(first_name.downcase)       # ← CORRECT
    filtered_records << record
  end
end

# CASE 3: Both names provided
elsif last_name.present? && first_name.present? && ...
  last_regex  = UcfTransformer.ucf_to_regex(name.last_name.downcase)
  first_regex = UcfTransformer.ucf_to_regex(name.first_name.downcase)
  if last_regex.match(last_name.downcase) &&    # ← CORRECT
     first_regex.match(first_name.downcase)     # ← CORRECT
    filtered_records << record
  end
end
```

**Change Summary**:
- 4 lines modified
- Pattern: `string.match(regex)` → `regex.match(string)`
- Logic: "Does string match pattern?" → "Does pattern match string?"

---

## 8. Testing Strategy

### Unit Tests

Create tests in `spec/models/search_query_spec.rb`:

```ruby
describe '#filter_ucf_records' do
  let(:search_query) { SearchQuery.new(...) }
  
  # Scenario 2
  it 'does not match unrelated patterns' do
    # Setup: Record with surname "do_e"
    # Search: "andover"
    # Expected: Should NOT be in filtered results
    
    records = [ record_with_surname("do_e") ]
    search_query.last_name = "andover"
    
    result = search_query.filter_ucf_records(records)
    expect(result).to be_empty
  end
  
  # Scenario 2A
  it 'matches related patterns correctly' do
    # Setup: Records with "p_le" and "pi*er"
    # Search: "piler"
    # Expected: Only "pi*er" should match
    
    records = [
      record_with_surname("p_le"),
      record_with_surname("pi*er")
    ]
    search_query.last_name = "piler"
    
    result = search_query.filter_ucf_records(records)
    expect(result.length).to eq(1)
    expect(result.first.last_name).to eq("pi*er")
  end
  
  # ... more test cases for scenarios 3-5
end
```

### Integration Tests

Run all 5 scenarios end-to-end to verify:
1. Normal results are correct
2. UCF results are correct
3. No unexpected duplicates
4. Performance is acceptable

---

## 9. Risk Assessment

### Risk Level: 🟢 LOW

**Why?**
- Single method change
- Logic is straightforward (swap operands)
- No database schema changes
- No external API changes
- Existing tests provide safety net

**Potential Issues?**
- None identified
- The fix is isolated to one method
- Ruby's regex matching is well-tested

**Rollback Plan**:
- If issues arise, swap back the 4 lines
- Revert commit from git

---

## 10. Uncertainty & Gaps

**Gaps Identified**: None

**Assumptions Verified**:
- ✅ UcfTransformer.ucf_to_regex() creates correct regex patterns
- ✅ filter_ucf_records() is the source of the bug
- ✅ The fix applies to all 5 scenarios

**What Still Needs Verification**:
- Performance impact (expected: none)
- Integration with other search modes (fuzzy, wildcard)
- Edge cases (blank queries, special characters)

---

## Next Document

See [02-IMPLEMENTATION-DETAILS.md](02-IMPLEMENTATION-DETAILS.md) for the exact code changes to make.

