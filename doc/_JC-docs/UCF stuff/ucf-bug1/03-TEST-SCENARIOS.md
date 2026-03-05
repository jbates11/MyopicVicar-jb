# UCF Search Results Bug - Test Scenarios & Verification

**Date**: March 4, 2026  
**Document Type**: Test Guide  
**Audience**: QA & Developers

---

## Overview

This document provides detailed test scenarios with expected results before and after the fix.

---

## Scenario Data

### Test Database Records

```
Registry: DEV, Harpford, St Gregory PR

Record 1:
  line: 647
  date: May 1854
  forename: samuel (M)
  surname: PILE (exact)

Record 2:
  line: 642
  date: 16 Nov 1853
  forename: mary ann (F)
  surname: P_LE (wildcard: p + any-char + le)

Record 3:
  line: 644 (first)
  date: 26 Jan 1854
  forename: joanna carter
  surname: P[IO]LE (bracket notation, display only)

Record 4:
  line: 644 (second)
  date: 26 Jan 1854
  forename: joanna carter8
  surname: PI*ER (wildcard: pi + any-chars + er)

Registry: STS, Kingsley, St Werburgh PR

Record 5:
  line: 3
  date: 21 Jan 1814
  forename: Den{1,2}is (wildcard: den + 1-2 chars + is)
  surname: HALL (exact)

Record 6:
  line: 4
  date: 22 Jan 1814
  forename: Grace
  surname: HAL{1,2} (wildcard: hal + 1-2 chars)

Record 7:
  line: 7
  date: 13 Apr 1814
  forename: John
  surname: DO_E (wildcard: d + any-char + e)

Record 8:
  line: 8
  date: 14 Apr 1814
  forename: Susan
  surname: ANDOVER (exact)
```

---

## Test Scenarios

### Scenario 1: Search Surname: pile

**Search Parameters**:
- Surname: pile
- Forename: (blank)
- Search Type: Exact

**Expected Normal Results (@search_results)**:
```
✓ samuel PILE
```
**Result**: Correct (exact match)

**Expected UCF Results (@ucf_results)**:
```
✓ mary ann P_LE
```

**Justification**: 
- Pattern `P_LE` = p + any-char + le
- "pile" = p + i + le → Matches pattern ✓
- Pattern matches search term correctly

**Status**: 
- Current: ✓ CORRECT
- After Fix: ✓ CORRECT

---

### Scenario 2: Search Surname: andover

**Search Parameters**:
- Surname: andover
- Forename: (blank)
- Search Type: Exact

**Expected Normal Results (@search_results)**:
```
✓ susan ANDOVER
```
**Result**: Correct (exact match)

**Expected UCF Results (@ucf_results)**:
```
(blank - no matches)
```

**Justification**:
- Pattern `DO_E` = d + any-char + e
- "andover" = a-n-d-o-v-e-r (7 chars, starts with 'a')
- Pattern expects 4-char word starting with 'd'
- No match ✓

**Status**:
- Current: ❌ WRONG (shows "john do_e")
- After Fix: ✓ CORRECT (blank)

**Root Cause**: Backwards matching logic  
**After Fix Reason**: Pattern `^do.e$` does NOT match "andover"

---

### Scenario 2A: Search Surname: piler

**Search Parameters**:
- Surname: piler
- Forename: (blank)
- Search Type: Exact

**Expected Normal Results (@search_results)**:
```
(blank - no exact match)
```
**Result**: Correct (no exact match exists)

**Expected UCF Results (@ucf_results)**:
```
✓ joanna carter8 PI*ER
```

**Justification**:
- Pattern `P_LE` = p + any-char + le
  - "piler" = p + i + l + e + r (5 chars)
  - Pattern expects 4 chars
  - NO match ✗
  
- Pattern `PI*ER` = pi + any-chars + er
  - "piler" = pi + l + er (5 chars)
  - Pattern matches ✓

**Status**:
- Current: ❌ WRONG (shows "mary ann p_le" and "joanna carter8 pi*er")
- After Fix: ✓ CORRECT (shows only "joanna carter8 pi*er")

**Root Cause**: Pattern `P_LE` incorrectly matches "piler" due to backwards logic  
**After Fix Reason**: Pattern `^p.le$` does NOT match "piler" (has extra chars)

---

### Scenario 3: Search Forename: denis

**Search Parameters**:
- Surname: (blank)
- Forename: denis
- Search Type: Exact

**Expected Normal Results (@search_results)**:
```
(blank - no exact match)
```
**Result**: Correct (no exact match)

**Expected UCF Results (@ucf_results)**:
```
(blank - no matches)
```

**Justification**:
- Pattern `DEN{1,2}IS` = den + 1-2 chars + is (6-7 chars)
- "denis" = d-e-n-i-s (5 chars)
- Pattern expects minimum 6 chars (den + 1 + is)
- NO match ✗

**Status**:
- Current: ✓ CORRECT
- After Fix: ✓ CORRECT

---

### Scenario 3A: Search Forename: dennis

**Search Parameters**:
- Surname: (blank)
- Forename: dennis
- Search Type: Exact

**Expected Normal Results (@search_results)**:
```
(blank - no exact match)
```
**Result**: Correct (no exact match)

**Expected UCF Results (@ucf_results)**:
```
✓ Den{1,2}is HALL
```

**Justification**:
- Pattern `DEN{1,2}IS` = den + 1-2 chars + is
- "dennis" = den + n + is (7 chars)
- Pattern matches: den + 1-char(n) + is = dennis ✓

**Status**:
- Current: ✓ CORRECT
- After Fix: ✓ CORRECT

---

### Scenario 3B: Search Forename: dennnis

**Search Parameters**:
- Surname: (blank)
- Forename: dennnis (3 n's)
- Search Type: Exact

**Expected Normal Results (@search_results)**:
```
(blank - no exact match)
```
**Result**: Correct (no exact match)

**Expected UCF Results (@ucf_results)**:
```
✓ Den{1,2}is HALL
```

**Justification**:
- Pattern `DEN{1,2}IS` = den + 1-2 chars + is
- "dennnis" = den + nn + is (8 chars)
- Pattern matches: den + 2-chars(nn) + is = dennnis ✓

**Status**:
- Current: ✓ CORRECT
- After Fix: ✓ CORRECT

---

### Scenario 4: Search Surname: hal

**Search Parameters**:
- Surname: hal
- Forename: (blank)
- Search Type: Exact

**Expected Normal Results (@search_results)**:
```
(blank - no exact match)
```
**Result**: Correct (no exact match)

**Expected UCF Results (@ucf_results)**:
```
(blank - no matches)
```

**Justification**:
- Pattern `HAL{1,2}` = hal + 1-2 chars (4-5 chars total)
- "hal" = h-a-l (3 chars)
- Pattern expects minimum 4 chars
- NO match ✗

**Status**:
- Current: ✓ CORRECT
- After Fix: ✓ CORRECT

---

### Scenario 4A: Search Surname: hall

**Search Parameters**:
- Surname: hall
- Forename: (blank)
- Search Type: Exact

**Expected Normal Results (@search_results)**:
```
✓ Den{1,2}is HALL
```
**Result**: Correct (exact match)

**Expected UCF Results (@ucf_results)**:
```
✓ Grace HAL{1,2}
```

**Justification**:
- Pattern `HALL` is exact match (not wildcard)
  - "hall" = h-a-l-l
  - Exact match ✓

- Pattern `HAL{1,2}` = hal + 1-2 chars
  - "hall" = hal + l (4 chars)
  - Pattern matches: hal + 1-char(l) = hall ✓

**Status**:
- Current: ❌ WRONG (shows "den{1,2}is hall" and "grace hal{1,2}")
- After Fix: ✓ CORRECT (shows only "grace hal{1,2}")

**Root Cause**: Pattern `DEN{1,2}IS` incorrectly matches "hall" due to backwards logic  
**After Fix Reason**: Pattern `^den.{1,2}is$` does NOT match "hall"

---

### Scenario 4B: Search Surname: halll

**Search Parameters**:
- Surname: halll (3 l's)
- Forename: (blank)
- Search Type: Exact

**Expected Normal Results (@search_results)**:
```
(blank - no exact match)
```
**Result**: Correct (no exact match - surname "HALL" is exactly 4 chars)

**Expected UCF Results (@ucf_results)**:
```
✓ Grace HAL{1,2}
```

**Justification**:
- Pattern `HAL{1,2}` = hal + 1-2 chars (4-5 chars)
- "halll" = hal + ll (5 chars)
- Pattern matches: hal + 2-chars(ll) = halll ✓

**Status**:
- Current: ❌ WRONG (shows "den{1,2}is hall" and "grace hal{1,2}")
- After Fix: ✓ CORRECT (shows only "grace hal{1,2}")

**Root Cause**: Pattern `DEN{1,2}IS` incorrectly matches "halll" due to backwards logic  
**After Fix Reason**: Pattern `^den.{1,2}is$` does NOT match "halll"

---

### Scenario 5: Search Forename: grace

**Search Parameters**:
- Surname: (blank)
- Forename: grace
- Search Type: Exact

**Expected Normal Results (@search_results)**:
```
✓ Grace HAL{1,2}
```
**Result**: Correct (exact match)

**Expected UCF Results (@ucf_results)**:
```
(blank - no matches)
```

**Justification**:
- The record with exact forename "Grace" is in normal results
- No UCF patterns contain the exact forename "grace"
- UCF results should be empty

**Status**:
- Current: ❌ WRONG (shows "grace hal{1,2}")
- After Fix: ✓ CORRECT (blank)

**Root Cause**: Same backwards logic, but result is inverted (showing as UCF when it's an exact match)  
**After Fix Reason**: No wildcard pattern in forename matches "grace" exactly

---

## Summary Table

### Before Fix (Current Behavior)

| Scenario | Search | Normal Results | UCF Results | Pass? |
|----------|--------|---|---|---|
| 1 | pile | samuel pile ✓ | p_le ✓ | ✓ PASS |
| 2 | andover | susan andover ✓ | do_e ❌ | ❌ FAIL |
| 2A | piler | blank ✓ | p_le ❌, pi*er ✓ | ❌ FAIL |
| 3 | denis | blank ✓ | blank ✓ | ✓ PASS |
| 3A | dennis | blank ✓ | den{1,2}is ✓ | ✓ PASS |
| 3B | dennnis | blank ✓ | den{1,2}is ✓ | ✓ PASS |
| 4 | hal | blank ✓ | blank ✓ | ✓ PASS |
| 4A | hall | den{1,2}is ✓ | den{1,2}is ❌, hal{1,2} ✓ | ❌ FAIL |
| 4B | halll | blank ✓ | den{1,2}is ❌, hal{1,2} ✓ | ❌ FAIL |
| 5 | grace | grace hal{1,2} ✓ | grace hal{1,2} ❌ | ❌ FAIL |

**Summary**: 5 passing, 5 failing

### After Fix (Expected Behavior)

| Scenario | Search | Normal Results | UCF Results | Pass? |
|----------|--------|---|---|---|
| 1 | pile | samuel pile ✓ | p_le ✓ | ✓ PASS |
| 2 | andover | susan andover ✓ | blank ✓ | ✓ PASS |
| 2A | piler | blank ✓ | pi*er ✓ | ✓ PASS |
| 3 | denis | blank ✓ | blank ✓ | ✓ PASS |
| 3A | dennis | blank ✓ | den{1,2}is ✓ | ✓ PASS |
| 3B | dennnis | blank ✓ | den{1,2}is ✓ | ✓ PASS |
| 4 | hal | blank ✓ | blank ✓ | ✓ PASS |
| 4A | hall | den{1,2}is ✓ | hal{1,2} ✓ | ✓ PASS |
| 4B | halll | blank ✓ | hal{1,2} ✓ | ✓ PASS |
| 5 | grace | grace hal{1,2} ✓ | blank ✓ | ✓ PASS |

**Summary**: 10 passing, 0 failing ✓ All tests pass!

---

## Testing in Rails Console

### Setup

```ruby
# Load the necessary classes
require 'search_query'
require 'search_record'

# Create test search records with wildcard patterns
records = [
  SearchRecord.create(
    first_name: 'mary ann',
    search_names: [{first_name: 'mary ann', last_name: 'p_le', type: 'p'}],
    search_date: '1853'
  ),
  SearchRecord.create(
    first_name: 'joanna carter8',
    search_names: [{first_name: 'joanna carter8', last_name: 'pi*er', type: 'p'}],
    search_date: '1854'
  ),
  SearchRecord.create(
    first_name: 'John',
    search_names: [{first_name: 'john', last_name: 'do_e', type: 'p'}],
    search_date: '1814'
  ),
  SearchRecord.create(
    first_name: 'Grace',
    search_names: [{first_name: 'grace', last_name: 'hal{1,2}', type: 'p'}],
    search_date: '1814'
  ),
  SearchRecord.create(
    first_name: 'Den{1,2}is',
    search_names: [{first_name: 'den{1,2}is', last_name: 'hall', type: 'p'}],
    search_date: '1814'
  )
]
```

### Test Case 1: pile

```ruby
sq = SearchQuery.new(last_name: 'pile')
ucf_records = [records[0]]  # p_le

result = sq.filter_ucf_records(ucf_records)
# Expected: 1 record (p_le matches pile)
puts "Scenario 1: #{result.count == 1 ? 'PASS' : 'FAIL'}"
```

### Test Case 2: andover

```ruby
sq = SearchQuery.new(last_name: 'andover')
ucf_records = [records[2]]  # do_e

result = sq.filter_ucf_records(ucf_records)
# Expected: 0 records (do_e does NOT match andover)
puts "Scenario 2: #{result.count == 0 ? 'PASS' : 'FAIL'}"
```

### Test Case 2A: piler

```ruby
sq = SearchQuery.new(last_name: 'piler')
ucf_records = [records[0], records[1]]  # p_le, pi*er

result = sq.filter_ucf_records(ucf_records)
# Expected: 1 record (only pi*er matches)
puts "Scenario 2A: #{result.count == 1 && result.first == records[1] ? 'PASS' : 'FAIL'}"
```

### Test Case 4A: hall

```ruby
sq = SearchQuery.new(last_name: 'hall')
ucf_records = [records[3], records[4]]  # hal{1,2}, den{1,2}is

result = sq.filter_ucf_records(ucf_records)
# Expected: 1 record (hal{1,2} matches, den{1,2}is does NOT)
puts "Scenario 4A: #{result.count == 1 && result.first == records[3] ? 'PASS' : 'FAIL'}"
```

### Test Case 5: grace

```ruby
sq = SearchQuery.new(first_name: 'grace')
ucf_records = [records[3]]  # Grace hal{1,2}

result = sq.filter_ucf_records(ucf_records)
# Expected: 0 records (no wildcard pattern in forename matches "grace")
puts "Scenario 5: #{result.count == 0 ? 'PASS' : 'FAIL'}"
```

---

## Performance Impact

**Expected**: None

**Reason**: 
- No additional database queries
- No algorithm changes (still O(n) matching)
- Regex compilation happens once per iteration (same as before)
- String/Regex method call is the same cost

**Validation**:
- Use Rails logger to measure time before/after
- Monitor query performance in production

---

## Rollback Success Criteria

If you need to rollback after the fix:

1. Verify that all test scenarios return to "before fix" behavior (5 passing, 5 failing)
2. Search appears broken again (shows wrong UCF results)
3. Normal results still work correctly
4. No database corruption

If any of these criteria are NOT met, investigate further.

---

## Sign-Off

- [ ] All test scenarios pass after fix
- [ ] No performance regression
- [ ] Code review completed
- [ ] Ready for production deployment

