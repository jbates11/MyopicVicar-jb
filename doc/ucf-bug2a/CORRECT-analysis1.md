# UCF Bug Analysis: Exact Match Search Returning Incorrectly Matched Uncertain Records

## Problem Statement

When a user performs an **exact match search** for a name, the system correctly returns exact matches but also incorrectly includes uncertain (UCF) records that should not appear.

### Example
- **Search**: Last Name = "andover", Exact Match = Yes, Record Type = Burial, County = Staffordshire, Place = Kingsley
- **Expected**: Only 1 exact match → "Susan ANDOVER"
- **Actual**: Multiple records including:
  - ✅ Susan ANDOVER (correct - exact match)
  - ❌ John DO_E (incorrect - uncertain result that shouldn't match)

### Why DO_E Shouldn't Appear
The source CSV data shows:
```
DO_E (with underscore indicating a single character wildcard)
```

The `_` could expand to any character: DOAE, DOBE, DOCE, DODE, ..., DOZE

None of these expansions equal "ANDOVER", so this record should NOT appear in an exact match search for "andover".

---

## Root Cause Analysis

### The Bug Location
**File**: `app/models/search_query.rb`, lines 463-570 in `filter_ucf_records` method

**The Problematic Code**:
```ruby
if last_name.downcase.match(regex)
  filtered_records << record
end
```

### How The Bug Works

#### Step 1: UCF Record Conversion
The DO_E record with uncertainty marker `_`:
- Original: `DO_E` (underscore is a wildcard)
- Converted by `UcfTransformer.ucf_to_regex`: `/do.e/` (underscore becomes `.` in regex)
- Possible expansions: DOAE, DOBE, DOCE, DODE, DOEE, DOGE, DOHE, ... DOZE

#### Step 2: Incorrect Matching Logic
When filtering results:
```ruby
# Current (BROKEN) logic
search_term = "andover"
regex = /do.e/
result = search_term.downcase.match(regex)  
# → Returns "dove" because "andover" CONTAINS "dove"!
```

#### Step 3: Substring Matching Bug
The `.match()` method checks if the search term **contains** a substring matching the pattern:
- "andover" contains the substring "dove"
- "dove" matches regex `/do.e/`  
- Therefore: `"andover".match(/do.e/)` → TRUE ✗ **WRONG!**
- Result: DO_E record is incorrectly included

#### Visual Representation
```
Search term:  a n d o v e r
              ↓ ↓ ↓ ↓ ↓ ↓ ↓
Pattern:          d o . e      (matches "dove" substring)
              
                  ✓ SUBSTRING MATCH FOUND (BUG!)
```

### The Logic Error

The current code asks: **"Does the search term contain any substring that matches the UCF pattern?"**

But it should ask: **"Could the exact search term be a valid expansion of the UCF pattern?"**

| Situation | Current Logic | Should Be |
|-----------|---|---|
| Search "andover", UCF "do_e" | "andover" contains "dove" which matches /do.e/ → TRUE | "andover" equals any expansion (doae, dobe, etc.) → FALSE |
| Search "dove", UCF "do_e" | "dove" matches /do.e/ → TRUE | "dove" is an expansion of /do.e/ → TRUE |
| Search "and*ver", UCF "do_e" | "and\w+" pattern doesn't match /do.e/ → FALSE | Wildcard matching logic (different) |

---

## Understanding UCF Uncertainty Markers

### The Source Data
```
STS,Kingsley,St Werburgh PR,7,13 Apr 1814,John,"","","","",DO_E,10,Youngers Green,"","",""
```

The last name field contains: `DO_E`

### What `_` Means
- `_` = single character wildcard (uncertainty in that one position)
- `*` = multi-character wildcard (one or more characters)
- `?` = unclear handwriting  
- `{1,2}` = choice between alternatives
- `[1,2]` = choice between alternatives

### Possible Expansions of DO_E
The underscore could be any letter A-Z (and potentially other characters):
- DOAE, DOBE, DOCE, DODE, DOEE, DOFE, DOGE, DOHE, DOIE, DOJE, DOKE, DOLE, DOME, DONE, DOOE, DOPE, DOQE, DORE, DOSE, DOTE, DOUE, DOVE, DOWE, DOXE, DOYE, DOZE

None of these match "ANDOVER".

---

## Impact Assessment

### Affected Searches
This bug affects **exact match searches only**:
- ✅ Exact match (fuzzy=false, no wildcards): **BUG OCCURS**
- ❌ Wildcard search (has * _ ? {): Different filtering logic applies
- ❌ Fuzzy search (fuzzy=true): Different filtering logic applies

### Why It Happens
Exact match searches use `filter_ucf_records` which was designed for **wildcard patterns in the SEARCH TERM**, not for **wildcard patterns in the UCF RECORDS**.

When the search term is a plain string (exact match) and the UCF record has wildcards, the substring matching approach breaks.

---

## The Solution

### Core Fix Approach
For exact match searches, the filtering logic must check if the search term would match **ALL possible expansions** of the UCF record, not just if it **contains a substring** matching the pattern.

### Two Implementation Options

#### Option A: Exact String Matching (Recommended - Simplest)
For exact match searches, disallow the wildcard pattern matching and instead do literal comparison:

```ruby
# Current code
if last_name.downcase.match(regex)  # Uses regex matching
  filtered_records << record
end

# Fixed code  
if exact_match_search?  # Add this check
  # For exact match: search term must exactly equal the UCF name (ignoring wildcards)
  # "andover".downcase == "do_e".downcase? → false ✓ Correct
  if last_name.downcase == name.last_name.downcase
    filtered_records << record
  end
else
  # For wildcard/fuzzy: use regex matching (existing logic)
  if last_name.downcase.match(regex)
    filtered_records << record
  end
end
```

**Advantage**: Simple, fast, clear intent  
**Disadvantage**: Ignores wildcard matching for exact searches (but that's actually correct!)

#### Option B: Full String Matching (More Complex)
Change from substring matching to full-string matching:

```ruby
# Instead of: search_term.match(pattern)
# Use: full_match where the entire search term must be an expansion

if last_name.downcase.match("^#{regex}$")  # ^ = start, $ = end
  filtered_records << record
end

# Example:
# "andover" matches /^do.e$/? → false ✓ Correct
# "dove" matches /^do.e$/? → true ✓ Correct  
# "dope" matches /^do.e$/? → true ✓ Correct
```

**Advantage**: Keeps wildcard logic, uses exact matching  
**Disadvantage**: More complex regex anchoring

### Recommended Fix: Option A
For an **exact match search**, the user is NOT searching for wildcard patterns. Therefore:
1. The system SHOULD query UCF records (to find uncertain versions of the exact name)
2. But it should match the exact search term against the literal name, NOT against the expanded pattern
3. Only include UCF records where the uncertain characters, when resolved, could plausibly match EXACTLY the search term

**Example**:
- Search: "andover" (exact)
- UCF record "And*ver": Would match (wildcard could resolve to "andover")
- UCF record "do_e": Would NOT match (uncertainty markers don't resolve to "andover")

---

## Implementation Plan

### Step 1: Add exact_match_search? Helper Method
```ruby
def exact_match_search?
  # Exact match: no wildcards in search, no fuzzy matching
  !query_contains_wildcard? && !fuzzy
end
```

### Step 2: Modify filter_ucf_records Method
**File**: `app/models/search_query.rb`, line 463+

Add conditional logic for exact match searches:
```ruby
def filter_ucf_records(records)
  # ... existing code ...
  
  record.search_names.each do |name|
    # ... existing filter checks ...
    
    if name.contains_wildcard_ucf?
      # Exact Match Search: Use literal string matching
      if exact_match_search?
        # For exact match, check if search terms literally match the UCF name
        # (ignoring what the wildcards could expand to)
        case
        when first_name.blank? && last_name.present? && name.last_name.present?
          # Compare exact strings
          if last_name.downcase == name.last_name.downcase
            filtered_records << record
          end
        when last_name.blank? && first_name.present? && name.first_name.present?
          if first_name.downcase == name.first_name.downcase
            filtered_records << record
          end
        when last_name.present? && first_name.present? &&
             name.last_name.present? && name.first_name.present?
          if last_name.downcase == name.last_name.downcase &&
             first_name.downcase == name.first_name.downcase
            filtered_records << record
          end
        end
      else
        # Wildcard/Fuzzy search: Use existing regex matching logic
        # (existing code continues as before)
        # ... regex matching logic ...
      end
    end
  end
  
  filtered_records
end
```

### Step 3: Add Comprehensive Tests
Test cases should verify:
1. Exact match searches DON'T return unrelated UCF records
2. Exact match searches DO return UCF records with uncertainty in the exact name
3. Wildcard searches still work normally
4. Fuzzy searches still work normally

---

## Verification: Before and After

### Before Fix
```ruby
# Search: "andover" (exact match)
# UCF Record: "do_e"

search_term = "andover"
ucf_name = "do_e"
regex = /do.e/

# Current (broken) logic
result = search_term.downcase.match(regex)  
# => #<MatchData "dove">  (found substring match)
# => Record INCLUDED ✗ WRONG

puts "Result: #{result}"  # Prints: dove
```

### After Fix
```ruby
# Search: "andover" (exact match)
# UCF Record: "do_e"

search_term = "andover"
ucf_name = "do_e"

# Fixed logic for exact match
if exact_match_search?
  # Compare exact strings
  result = (search_term.downcase == ucf_name.downcase)
else
  # Use regex
  result = search_term.downcase.match(/do.e/)
end

# => false ✓ CORRECT
# => Record NOT included

puts "Result: #{result}"  # Prints: false
```

---

## Why The System SHOULD Query UCF

The user's clarification is correct: **The system should query UCF ALWAYS if conditions are met.**

This is appropriate because:
1. UCF records contain UNCERTAIN versions of names
2. For fuzzy/wildcard searches, unclear names ARE relevant
3. For exact match searches, unclear names should only appear if they could match the exact term

**Example of correct UCF inclusion in exact match**:
- Search: "andover" (exact)
- UCF record: "And*ver" → Could expand to "andover" → INCLUDE ✓
- UCF record: "do_e" → Expands to do + any char + e, never "andover" → EXCLUDE ✓

---

## Code Changes Summary

| Component | Change | Location |
|-----------|--------|----------|
| `exact_match_search?` | Add new method | Before line 334 |
| `filter_ucf_records` | Add exact match conditional | Line 463+ |
| Tests | Add comprehensive test cases | New file: `spec/models/search_query/exact_match_filter_ucf_spec.rb` |

---

## Related Files (No Changes Needed)

- `app/models/search_record.rb` - Contains `contains_wildcard_ucf?` (works correctly)
- `lib/ucf_transformer.rb` - Regex conversion logic (works correctly)
- `app/controllers/search_queries_controller.rb` - Controller (no change needed)
- `app/views/search_queries/show.html.erb` - View (no change needed)

The issue is purely in the **matching logic** of `filter_ucf_records`, not in the data structures or display logic.
