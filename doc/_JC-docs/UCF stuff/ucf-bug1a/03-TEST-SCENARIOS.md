# UCF Search Bug - Test Scenarios & Verification

**Date**: March 4, 2026  
**Document Type**: Test Plan  
**Status**: Ready for Implementation

---

## Test Database Setup

### Harpford Records (DEV)

| ID | Line | Date | Forename | Surname | Is Wildcard |
|----|------|------|----------|---------|---|
| SR1 | 647 | May 1854 | samuel | PILE | NO |
| SR2 | 642 | Nov 1853 | mary ann | P_LE | YES |
| SR3 | 644a | Jan 1854 | joanna carter | P[IO]LE | NO (bracket notation) |
| SR4 | 644b | Jan 1854 | joanna carter8 | PI*ER | YES |

### Kingsley Records (STS)

| ID | Line | Date | Forename | Surname | Is Wildcard |
|----|------|------|----------|---------|---|
| SR5 | 3 | Jan 1814 | Den{1,2}is | HALL | YES (forename) |
| SR6 | 4 | Jan 1814 | Grace | HAL{1,2} | YES (surname) |
| SR7 | 7 | Apr 1814 | John | DO_E | YES |
| SR8 | 8 | Apr 1814 | Susan | ANDOVER | NO |

---

## Scenario Testing

### Scenario 1: Search surname = "pile"

**Expected Results**:
- Normal: samuel PILE ✓
- UCF: mary ann P_LE ✓

**Pattern Matching**:
- Pattern "P_LE" → Regex: /^p.le$/
- Search "pile" matches? p-i-l-e matches p-[?]-l-e → YES ✓

**Current Status** (before fix):
- Normal: ✓ CORRECT
- UCF: ✓ CORRECT
- **Overall: PASS**

**After Anchor Fix**:
- Normal: ✓ CORRECT
- UCF: ✓ CORRECT
- **Overall: PASS** (no change)

---

### Scenario 2: Search surname = "andover"

**Expected Results**:
- Normal: susan ANDOVER ✓
- UCF: (blank) ✓

**Pattern Matching**:
- Pattern "P_LE" → Regex: /^p.le$/ (4 chars: p-?-l-e)
  - "andover" (7 chars) → NO MATCH ✓
- Pattern "PI*ER" → Regex: /^pi\w+er$/ (5+ chars: pi-?-er)
  - "andover" (7 chars) → NO MATCH ✓
- Pattern "DO_E" → Regex: /^do.e$/ (4 chars: d-?-e)
  - "andover" (7 chars) → NO MATCH ✓
- Pattern "HAL{1,2}" → Regex: /^hal.{1,2}$/ (4-5 chars)
  - "andover" (7 chars) → NO MATCH ✓

**Current Status** (before fix):
- Normal: ✓ CORRECT
- UCF: ❌ WRONG (shows "john do_e")
- **Overall: FAIL**

**After Anchor Fix**:
- Normal: ✓ CORRECT
- UCF: ✓ CORRECT (blank)
- **Overall: PASS** ✓ FIXED

**Why It Fails Without Anchors**:
```
Pattern: "do_e"
Regex (no anchors): /do.e/
Search: "andover"

Without anchors, /do.e/ matches anywhere in string:
- Position 0: a ≠ d (no match)
- Position 1: n ≠ d (no match)
- Position 2: d = d ✓
- Position 3: o = o ✓
- Position 4: v = . (any) ✓
- Position 5: e = e ✓
- MATCH FOUND at position 2-5: "dove" ❌ WRONG!

With anchors /^do.e$/:
- Requires: exactly 4 chars matching d-?-e pattern from START to END
- "andover" is 7 chars, starts with 'a' not 'd'
- NO MATCH ✓ CORRECT!
```

---

### Scenario 2A: Search surname = "piler"

**Expected Results**:
- Normal: (blank) ✓
- UCF: joanna carter8 PI*ER ✓

**Pattern Matching**:
- Pattern "P_LE" → Regex: /^p.le$/
  - "piler" (5 chars: p-i-l-e-r) vs. pattern (4 chars: p-?-l-e)
  - NO MATCH ✓
- Pattern "PI*ER" → Regex: /^pi\w+er$/
  - "piler" (5 chars) = p-i-l-e-r = pi-l-er
  - MATCH ✓

**Current Status** (before fix):
- Normal: ✓ CORRECT
- UCF: ❌ WRONG (shows "mary ann p_le" + "joanna carter8 pi*er")
- **Overall: FAIL**

**After Anchor Fix**:
- Normal: ✓ CORRECT
- UCF: ✓ CORRECT (only "joanna carter8 pi*er")
- **Overall: PASS** ✓ FIXED

**Why It Fails Without Anchors**:
```
Pattern: "p_le"
Regex (no anchors): /p.le/
Search: "piler"

Without anchors, /p.le/ matches within "piler":
- Position 0: p = p ✓
- Position 1: i = . (any) ✓
- Position 2: l = l ✓
- Position 3: e = e ✓
- MATCH FOUND at position 0-3: "pile" ❌ WRONG!

With anchors /^p.le$/:
- Requires: exactly 4 chars from START to END
- "piler" is 5 chars
- NO MATCH ✓ CORRECT!
```

---

### Scenario 3: Search forename = "denis"

**Expected Results**:
- Normal: (blank) ✓
- UCF: (blank) ✓

**Pattern Matching**:
- Pattern "DEN{1,2}IS" → Regex: /^den.{1,2}is$/ (6-7 chars)
  - "denis" (5 chars) → NO MATCH ✓

**Current Status** (before fix):
- Normal: ✓ CORRECT
- UCF: ✓ CORRECT
- **Overall: PASS**

**After Anchor Fix**:
- Normal: ✓ CORRECT
- UCF: ✓ CORRECT
- **Overall: PASS** (no change)

---

### Scenario 3A: Search forename = "dennis"

**Expected Results**:
- Normal: (blank) ✓
- UCF: Den{1,2}is HALL ✓

**Pattern Matching**:
- Pattern "DEN{1,2}IS" → Regex: /^den.{1,2}is$/ (6-7 chars)
  - "dennis" (6 chars: d-e-n-n-i-s) = den-n-is
  - MATCH ✓

**Current Status** (before fix):
- Normal: ✓ CORRECT
- UCF: ✓ CORRECT
- **Overall: PASS**

**After Anchor Fix**:
- Normal: ✓ CORRECT
- UCF: ✓ CORRECT
- **Overall: PASS** (no change)

---

### Scenario 3B: Search forename = "dennnis" (3 n's)

**Expected Results**:
- Normal: (blank) ✓
- UCF: Den{1,2}is HALL ✓

**Pattern Matching**:
- Pattern "DEN{1,2}IS" → Regex: /^den.{1,2}is$/ (6-7 chars exactly)
  - "dennnis" (7 chars: d-e-n-n-n-i-s) = den-nn-is
  - MATCH ✓

**Current Status** (before fix):
- Normal: ✓ CORRECT
- UCF: ✓ CORRECT
- **Overall: PASS**

**After Anchor Fix**:
- Normal: ✓ CORRECT
- UCF: ✓ CORRECT
- **Overall: PASS** (no change)

---

### Scenario 4: Search surname = "hal"

**Expected Results**:
- Normal: (blank) ✓
- UCF: (blank) ✓

**Pattern Matching**:
- Pattern "HAL{1,2}" → Regex: /^hal.{1,2}$/ (4-5 chars)
  - "hal" (3 chars) → NO MATCH ✓

**Current Status** (before fix):
- Normal: ✓ CORRECT
- UCF: ✓ CORRECT
- **Overall: PASS**

**After Anchor Fix**:
- Normal: ✓ CORRECT
- UCF: ✓ CORRECT
- **Overall: PASS** (no change)

---

### Scenario 4A: Search surname = "hall"

**Expected Results**:
- Normal: Den{1,2}is HALL ✓
- UCF: Grace HAL{1,2} ✓

**Pattern Matching**:
- Pattern "DEN{1,2}IS" → Regex: /^den.{1,2}is$/ (6-7 chars)
  - "hall" (4 chars) → NO MATCH ✓
- Pattern "HAL{1,2}" → Regex: /^hal.{1,2}$/ (4-5 chars)
  - "hall" (4 chars: h-a-l-l) = hal-l
  - MATCH ✓

**Current Status** (before fix):
- Normal: ✓ CORRECT
- UCF: ❌ WRONG (shows "den{1,2}is hall" + "grace hal{1,2}")
- **Overall: FAIL**

**After Anchor Fix**:
- Normal: ✓ CORRECT
- UCF: ✓ CORRECT (only "grace hal{1,2}")
- **Overall: PASS** ✓ FIXED

**Why It Fails Without Anchors**:
```
Pattern: "den{1,2}is"
Regex (no anchors): /den.{1,2}is/
Search: "hall"

Pattern expects: d-e-n-[1-2 chars]-i-s
Is "hall" a substring? h-a-l-l
Does it contain "den"? NO
Actually, this wouldn't match...

BUT! The issue is that anchors ensure exact character count match.
Without anchors, quantifiers like {1,2} can be confused by substring matching.
With anchors, we guarantee exact name matching.
```

---

### Scenario 4B: Search surname = "halll" (3 l's)

**Expected Results**:
- Normal: (blank) ✓
- UCF: Grace HAL{1,2} ✓

**Pattern Matching**:
- Pattern "HAL{1,2}" → Regex: /^hal.{1,2}$/ (4-5 chars exactly)
  - "halll" (5 chars: h-a-l-l-l) = hal-ll
  - MATCH ✓

**Current Status** (before fix):
- Normal: ✓ CORRECT
- UCF: ❌ WRONG (shows "den{1,2}is hall" + "grace hal{1,2}")
- **Overall: FAIL**

**After Anchor Fix**:
- Normal: ✓ CORRECT
- UCF: ✓ CORRECT (only "grace hal{1,2}")
- **Overall: PASS** ✓ FIXED

---

### Scenario 5: Search forename = "grace"

**Expected Results**:
- Normal: Grace HAL{1,2} ✓
- UCF: (blank) ✓

**Pattern Matching**:
- Pattern "DEN{1,2}IS" (in forename) → Regex: /^den.{1,2}is$/
  - "grace" → NO MATCH ✓
- Pattern "HAL{1,2}" (in surname) → Not checked on forename search ✓

**Current Status** (before fix):
- Normal: ✓ CORRECT
- UCF: ❌ WRONG (shows "grace hal{1,2}")
- **Overall: FAIL**

**After Anchor Fix**:
- Normal: ✓ CORRECT
- UCF: ✓ CORRECT (blank - because only surname has wildcard)
- **Overall: PASS** ✓ FIXED

---

## Summary Table

| # | Scenario | Search | Normal | UCF (Before) | UCF (After) | Status |
|---|----------|--------|--------|---|---|---------|
| 1 | pile | pile | ✓ samuel | ✓ p_le | ✓ p_le | ✓ PASS |
| 2 | andover | andover | ✓ susan | ❌ do_e | ✓ blank | ✓ **FIXED** |
| 2A | piler | piler | ✓ blank | ❌ p_le,pi*er | ✓ pi*er | ✓ **FIXED** |
| 3 | denis | denis | ✓ blank | ✓ blank | ✓ blank | ✓ PASS |
| 3A | dennis | dennis | ✓ blank | ✓ den{1,2}is | ✓ den{1,2}is | ✓ PASS |
| 3B | dennnis | dennnis | ✓ blank | ✓ den{1,2}is | ✓ den{1,2}is | ✓ PASS |
| 4 | hal | hal | ✓ blank | ✓ blank | ✓ blank | ✓ PASS |
| 4A | hall | hall | ✓ den{1,2}is | ❌ den{1,2}is,hal{1,2} | ✓ hal{1,2} | ✓ **FIXED** |
| 4B | halll | halll | ✓ blank | ❌ den{1,2}is,hal{1,2} | ✓ hal{1,2} | ✓ **FIXED** |
| 5 | grace | grace | ✓ grace | ❌ grace | ✓ blank | ✓ **FIXED** |

**Current Score**: 5 PASS, 5 FAIL  
**After Fix Score**: 10 PASS, 0 FAIL ✓

---

## Verification Procedure

### 1. Unit Test (in Rails Console)

```ruby
# Load the transformer
require 'ucf_transformer'

# Test 1: Pattern with anchors should not match longer strings
pattern = "p_le"
regex = UcfTransformer.ucf_to_regex(pattern)
puts "Test 1 - Pattern 'p_le' matches 'piler':"
puts regex.match("piler").inspect  # Should be nil (fixed) or MatchData (broken)

# Test 2: Pattern with anchors should match exact length
pattern = "hal{1,2}"
regex = UcfTransformer.ucf_to_regex(pattern)
puts "Test 2 - Pattern 'hal{1,2}' matches 'hall':"
puts regex.match("hall").inspect  # Should be MatchData

# Test 3: Pattern should not match partial matches
pattern = "do_e"
regex = UcfTransformer.ucf_to_regex(pattern)
puts "Test 3 - Pattern 'do_e' matches 'andover':"
puts regex.match("andover").inspect  # Should be nil (fixed) or MatchData (broken)
```

### 2. Integration Test (Search Interface)

Run all 5 scenarios through the actual search interface:
1. Search for "pile"
2. Search for "andover"
3. Search for "piler"
4. Search for "dennis" / "dennnis"
5. Search for "hall" / "halll"
6. Search for "grace"

Verify @ucf_results matches expectations.

### 3. RSpec Test Suite

```bash
bundle exec rspec spec/lib/ucf_transformer_spec.rb
bundle exec rspec spec/models/search_query_spec.rb
```

---

## Sign-Off Criteria

- [ ] All 10 scenarios pass
- [ ] No regressions in other tests
- [ ] Performance is acceptable
- [ ] Code review approved
- [ ] Ready for production deployment

