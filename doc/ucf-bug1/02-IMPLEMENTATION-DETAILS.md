# UCF Search Results Bug - Implementation Details

**Date**: March 4, 2026  
**Document Type**: Implementation Guide  
**Audience**: Developers  
**Complexity**: Simple (4 line changes)

---

## Overview

This document provides the exact code changes required to fix the UCF search results bug. All changes are in a single method: `SearchQuery#filter_ucf_records()`.

---

## File: app/models/search_query.rb

### Location: Lines 520-565

### Complete Method (Before & After)

#### BEFORE (Current - BROKEN CODE)

```ruby
def filter_ucf_records(records)
  Rails.logger.info "\n[filter_ucf_records] starting with #{records.size} raw records"
  Rails.logger.info "[filter_ucf_records] Start loop of search records\n"

  filtered_records = []

  records.each do |raw_record|
    Rails.logger.info "[filter_ucf_records] Processing raw search record: #{raw_record.inspect}"

    record = SearchRecord.record_id(raw_record.to_s).first
    Rails.logger.info "[filter_ucf_records] Search Record:\n#{record.inspect}"

    next if record.blank?

    if record.search_date.blank?
      Rails.logger.info "[filter_ucf_records] Skipping search record: blank search_date"
      next
    end

    if record.search_date.match(UCF) && !record.search_date.match(VALID_YEAR)
      Rails.logger.info "[filter_ucf_records] Skipping search record: search_date matches UCF"
      next
    end

    if record_type.present? && record.record_type != record_type
      Rails.logger.info "[filter_ucf_records] Skipping search record: record_type mismatch"
      next
    end

    if start_year.present?
      year = record.search_date.to_i
      if year < start_year || year > end_year
        Rails.logger.info "[filter_ucf_records] Skipping search record: year #{year} outside #{start_year}-#{end_year}"
        next
      end
    end

    Rails.logger.info "\n[filter_ucf_records] Start loop of search name(s)"
    record.search_names.each do |name|
      Rails.logger.info "\n+++ [filter_ucf_records] Evaluating search name: #{name.attributes}"

      unless name.type == SearchRecord::PersonType::PRIMARY || inclusive || witness
        Rails.logger.info "[filter_ucf_records] Skipping name: not PRIMARY and no inclusive/witness flags\n"
        next
      end

      begin
        if name.contains_wildcard_ucf?
          Rails.logger.info "[filter_ucf_records] Wildcard UCF detected for name"

          # CASE 1: Only last name provided
          if first_name.blank? && last_name.present? && name.last_name.present?
            regex = UcfTransformer.ucf_to_regex(name.last_name.downcase)

            Rails.logger.info "[filter_ucf_records] last_name_regex: #{regex}"

            if last_name.downcase.match(regex)
              Rails.logger.info "[filter_ucf_records] Matched last name wildcard"
              filtered_records << record
            end

          # CASE 2: Only first name provided
          elsif last_name.blank? && first_name.present? && name.first_name.present?
            regex = UcfTransformer.ucf_to_regex(name.first_name.downcase)

            Rails.logger.info "[filter_ucf_records] first_name_regex: #{regex}"

            if first_name.downcase.match(regex)
              Rails.logger.info "[filter_ucf_records] Matched first name wildcard"
              filtered_records << record
            end

          # CASE 3: Both names provided
          elsif last_name.present? && first_name.present? &&
                name.last_name.present? && name.first_name.present?

            last_regex  = UcfTransformer.ucf_to_regex(name.last_name.downcase)
            first_regex = UcfTransformer.ucf_to_regex(name.first_name.downcase)

            Rails.logger.info "[filter_ucf_records] last_regex: #{last_regex} , first_regex: #{first_regex}"

            if last_name.downcase.match(last_regex) &&
              first_name.downcase.match(first_regex)
              Rails.logger.info "[filter_ucf_records] Matched both first and last name wildcards"
              filtered_records << record
            end
          end
        end
      rescue RegexpError => e
        Rails.logger.error "[filter_ucf_records] RegexpError for name #{name.inspect}: #{e.message}"
      end
    end
    Rails.logger.info "[filter_ucf_records] End loop of search names\n"
  end
  Rails.logger.info "[filter_ucf_records] End loop of search records\n"

  Rails.logger.info "[filter_ucf_records] filter_ucf_records: returning #{filtered_records.size} filtered records\n"

  filtered_records
end
```

#### AFTER (Fixed - CORRECT CODE)

```ruby
def filter_ucf_records(records)
  Rails.logger.info "\n[filter_ucf_records] starting with #{records.size} raw records"
  Rails.logger.info "[filter_ucf_records] Start loop of search records\n"

  filtered_records = []

  records.each do |raw_record|
    Rails.logger.info "[filter_ucf_records] Processing raw search record: #{raw_record.inspect}"

    record = SearchRecord.record_id(raw_record.to_s).first
    Rails.logger.info "[filter_ucf_records] Search Record:\n#{record.inspect}"

    next if record.blank?

    if record.search_date.blank?
      Rails.logger.info "[filter_ucf_records] Skipping search record: blank search_date"
      next
    end

    if record.search_date.match(UCF) && !record.search_date.match(VALID_YEAR)
      Rails.logger.info "[filter_ucf_records] Skipping search record: search_date matches UCF"
      next
    end

    if record_type.present? && record.record_type != record_type
      Rails.logger.info "[filter_ucf_records] Skipping search record: record_type mismatch"
      next
    end

    if start_year.present?
      year = record.search_date.to_i
      if year < start_year || year > end_year
        Rails.logger.info "[filter_ucf_records] Skipping search record: year #{year} outside #{start_year}-#{end_year}"
        next
      end
    end

    Rails.logger.info "\n[filter_ucf_records] Start loop of search name(s)"
    record.search_names.each do |name|
      Rails.logger.info "\n+++ [filter_ucf_records] Evaluating search name: #{name.attributes}"

      unless name.type == SearchRecord::PersonType::PRIMARY || inclusive || witness
        Rails.logger.info "[filter_ucf_records] Skipping name: not PRIMARY and no inclusive/witness flags\n"
        next
      end

      begin
        if name.contains_wildcard_ucf?
          Rails.logger.info "[filter_ucf_records] Wildcard UCF detected for name"

          # CASE 1: Only last name provided
          if first_name.blank? && last_name.present? && name.last_name.present?
            regex = UcfTransformer.ucf_to_regex(name.last_name.downcase)

            Rails.logger.info "[filter_ucf_records] last_name_regex: #{regex}"

            if regex.match(last_name.downcase)
              Rails.logger.info "[filter_ucf_records] Matched last name wildcard"
              filtered_records << record
            end

          # CASE 2: Only first name provided
          elsif last_name.blank? && first_name.present? && name.first_name.present?
            regex = UcfTransformer.ucf_to_regex(name.first_name.downcase)

            Rails.logger.info "[filter_ucf_records] first_name_regex: #{regex}"

            if regex.match(first_name.downcase)
              Rails.logger.info "[filter_ucf_records] Matched first name wildcard"
              filtered_records << record
            end

          # CASE 3: Both names provided
          elsif last_name.present? && first_name.present? &&
                name.last_name.present? && name.first_name.present?

            last_regex  = UcfTransformer.ucf_to_regex(name.last_name.downcase)
            first_regex = UcfTransformer.ucf_to_regex(name.first_name.downcase)

            Rails.logger.info "[filter_ucf_records] last_regex: #{last_regex} , first_regex: #{first_regex}"

            if last_regex.match(last_name.downcase) &&
              first_regex.match(first_name.downcase)
              Rails.logger.info "[filter_ucf_records] Matched both first and last name wildcards"
              filtered_records << record
            end
          end
        end
      rescue RegexpError => e
        Rails.logger.error "[filter_ucf_records] RegexpError for name #{name.inspect}: #{e.message}"
      end
    end
    Rails.logger.info "[filter_ucf_records] End loop of search names\n"
  end
  Rails.logger.info "[filter_ucf_records] End loop of search records\n"

  Rails.logger.info "[filter_ucf_records] filter_ucf_records: returning #{filtered_records.size} filtered records\n"

  filtered_records
end
```

---

## Diff Summary

### Change 1: CASE 1 (Last Name Only)

**Line**: 524  
**Old**: `if last_name.downcase.match(regex)`  
**New**: `if regex.match(last_name.downcase)`  

```diff
      if first_name.blank? && last_name.present? && name.last_name.present?
        regex = UcfTransformer.ucf_to_regex(name.last_name.downcase)

        Rails.logger.info "[filter_ucf_records] last_name_regex: #{regex}"

-       if last_name.downcase.match(regex)
+       if regex.match(last_name.downcase)
          Rails.logger.info "[filter_ucf_records] Matched last name wildcard"
          filtered_records << record
        end
```

### Change 2: CASE 2 (First Name Only)

**Line**: 536  
**Old**: `if first_name.downcase.match(regex)`  
**New**: `if regex.match(first_name.downcase)`  

```diff
      elsif last_name.blank? && first_name.present? && name.first_name.present?
        regex = UcfTransformer.ucf_to_regex(name.first_name.downcase)

        Rails.logger.info "[filter_ucf_records] first_name_regex: #{regex}"

-       if first_name.downcase.match(regex)
+       if regex.match(first_name.downcase)
          Rails.logger.info "[filter_ucf_records] Matched first name wildcard"
          filtered_records << record
        end
```

### Change 3: CASE 3 (Both Names) - Line 1

**Line**: 552  
**Old**: `if last_name.downcase.match(last_regex) &&`  
**New**: `if last_regex.match(last_name.downcase) &&`  

```diff
        Rails.logger.info "[filter_ucf_records] last_regex: #{last_regex} , first_regex: #{first_regex}"

-       if last_name.downcase.match(last_regex) &&
-         first_name.downcase.match(first_regex)
+       if last_regex.match(last_name.downcase) &&
+         first_regex.match(first_name.downcase)
          Rails.logger.info "[filter_ucf_records] Matched both first and last name wildcards"
          filtered_records << record
        end
```

### Change 4: CASE 3 (Both Names) - Line 2

**Line**: 553  
**Old**: `first_name.downcase.match(first_regex)`  
**New**: `first_regex.match(first_name.downcase)`  

(See Change 3 above - both lines are modified together)

---

## Detailed Explanation

### Why These Changes Fix the Bug

#### Pattern Matching Direction

**BEFORE (Broken)**:
```ruby
last_name.downcase.match(regex)
```
- Asks: "Does the search term contain this pattern as a substring?"
- Example: Does "andover" match /^do.e$/?
- Problem: String method `match()` checks if pattern is found anywhere in string
- Result: False positives due to backwards logic

**AFTER (Fixed)**:
```ruby
regex.match(last_name.downcase)
```
- Asks: "Does this pattern match the search term?"
- Example: Does /^do.e$/ match "andover"?
- Solution: Regex method `match()` checks entire string against pattern
- Result: Accurate matching according to UCF rules

#### Ruby Semantics

Both patterns are technically valid Ruby, but have different meanings:

```ruby
# String#match(regexp) → MatchData or nil
"hello".match(/ll/)       # → MatchData (found 'll' in string)
"hello".match(/^ll/)      # → nil (pattern doesn't match from start)

# Regexp#match(string) → MatchData or nil
/ll/.match("hello")       # → MatchData (pattern found in string)
/^ll/.match("hello")      # → nil (pattern doesn't match from start)
```

For UCF patterns with anchors (`^...$`), we need `Regexp#match()` to enforce the full pattern match, not partial substring matching.

---

## Testing

### Manual Test Cases

After applying changes, verify with manual tests:

```ruby
# In Rails console
sq = SearchQuery.create(last_name: 'andover', ...)
sr1 = build_search_record_with_names('john', 'do_e')
sr2 = build_search_record_with_names('susan', 'ANDOVER')

# UCF filter should only match exact pattern matches
results = sq.filter_ucf_records([sr1, sr2])

# Expected: Empty array (no patterns match 'andover')
puts "Test 1 (andover): #{results.empty? ? 'PASS' : 'FAIL'}"

# Test 2: piler should match pi*er but not p_le
sq2 = SearchQuery.create(last_name: 'piler', ...)
sr3 = build_search_record_with_names('anna', 'p_le')
sr4 = build_search_record_with_names('john', 'pi*er')

results2 = sq2.filter_ucf_records([sr3, sr4])

# Expected: Only sr4
puts "Test 2 (piler): #{results2.count == 1 && results2.first == sr4 ? 'PASS' : 'FAIL'}"
```

### Automated Test Cases

```bash
# Run existing test suite
bundle exec rspec spec/models/search_query_spec.rb

# Run with focus on UCF tests
bundle exec rspec spec/models/search_query_spec.rb -f d | grep -i ucf
```

---

## Rollback Instructions

If issues occur after deployment:

```bash
# Revert the 4 line changes
git revert -n <commit_hash>

# OR manually swap back the 4 lines:
# Line 524:  last_name.downcase.match(regex) ← instead of regex.match(last_name.downcase)
# Line 536:  first_name.downcase.match(regex) ← instead of regex.match(first_name.downcase)
# Line 552:  last_name.downcase.match(last_regex) && first_name.downcase.match(first_regex)
# Line 553:  (same as line 552)

git add app/models/search_query.rb
git commit -m "Revert UCF filter fix"
```

---

## Implementation Checklist

- [ ] Read and understand [01-ROOT-CAUSE-ANALYSIS.md](01-ROOT-CAUSE-ANALYSIS.md)
- [ ] Backup current [app/models/search_query.rb](app/models/search_query.rb)
- [ ] Apply the 4-line changes (use multicopy/paste approach)
- [ ] Save file and verify syntax: `bundle exec ruby -c app/models/search_query.rb`
- [ ] Run tests: `bundle exec rspec spec/models/search_query_spec.rb`
- [ ] Test all 5 scenarios manually
- [ ] Commit with message: "Fix: Reverse matching direction in UCF filter"
- [ ] Create pull request for review
- [ ] Deploy to staging
- [ ] Deploy to production

---

## Next Document

See [03-TEST-SCENARIOS.md](03-TEST-SCENARIOS.md) for expected results after the fix.

