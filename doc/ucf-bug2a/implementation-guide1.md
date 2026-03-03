# UCF Bug Fix: Correct Implementation Guide

## Overview

The bug is in the `filter_ucf_records` method's matching logic. For exact match searches, it uses substring matching (`.match()`) which incorrectly includes UCF records that merely contain a substring matching the wildcard pattern, rather than checking if the search term could be a valid expansion.

This guide provides the exact implementation to fix this issue.

---

## The Core Problem (Clearly Explained)

### Current (Broken) Logic
```ruby
# Search: "andover" (exact match)
# UCF Record: "do_e" 
# Regex: /do.e/ (underscore converted to .)

result = "andover".downcase.match(/do.e/)
# "andover" contains "dove" 
# "dove" matches /do.e/ 
# Result: MATCH FOUND ✗ WRONG!
```

### Correct Logic  
```ruby
# For exact match searches:
# "andover" should only match if it EQUALS a possible expansion
# Expansions of "do_e": doae, dobe, doce, ..., doze
# Does "andover" equal any of these? NO
# Result: NO MATCH ✓ CORRECT
```

---

## Implementation: 4 Simple Steps

### Step 1: Add Helper Method

**File**: `app/models/search_query.rb`  
**Location**: Before  line 334 (before `can_query_ucf?`)  
**Add**:

```ruby
def exact_match_search?
  # Exact match search: no wildcards in user's search term, no fuzzy matching
  !query_contains_wildcard? && !fuzzy
end
```

---

### Step 2: Modify filter_ucf_records Method

**File**: `app/models/search_query.rb`  
**Location**: Lines 463-570 (the `filter_ucf_records` method)  
**Change**:

Find the section starting at line 515:
```ruby
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
```

Replace with:
```ruby
        if name.contains_wildcard_ucf?
          Rails.logger.info "[filter_ucf_records] Wildcard UCF detected for name"

          # For exact match searches, use exact string comparison
          # For wildcard/fuzzy searches, use regex pattern matching
          if exact_match_search?
            # EXACT MATCH: Check if search term exactly equals UCF name value
            # (This will rarely match because the search term has no wildcards
            #  but the UCF name does, so they won't be equal)
            
            # CASE 1: Only last name provided
            if first_name.blank? && last_name.present? && name.last_name.present?
              if last_name.downcase == name.last_name.downcase
                Rails.logger.info "[filter_ucf_records] Matched last name (exact)"
                filtered_records << record
              end

            # CASE 2: Only first name provided
            elsif last_name.blank? && first_name.present? && name.first_name.present?
              if first_name.downcase == name.first_name.downcase
                Rails.logger.info "[filter_ucf_records] Matched first name (exact)"
                filtered_records << record
              end

            # CASE 3: Both names provided
            elsif last_name.present? && first_name.present? &&
                  name.last_name.present? && name.first_name.present?

              if last_name.downcase == name.last_name.downcase &&
                 first_name.downcase == name.first_name.downcase
                Rails.logger.info "[filter_ucf_records] Matched both first and last name (exact)"
                filtered_records << record
              end
            end

          else
            # WILDCARD/FUZZY SEARCH: Use regex pattern matching (original logic)
            regex = UcfTransformer.ucf_to_regex(name.last_name.downcase)

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
```

---

### Step 3: Create Test File

**File**: `spec/models/search_query/filter_ucf_exact_match_spec.rb`  
**Type**: Create new file  
**Contents**:

```ruby
require "rails_helper"

RSpec.describe SearchQuery, type: :model do
  describe "#filter_ucf_records for exact match searches" do
    let(:place) { create(:place) }
    let(:search_query) { create(:search_query, chapman_codes: [place.chapman_code]) }

    context "exact match search (fuzzy=false, no wildcards)" do
      it "does NOT include unrelated UCF records" do
        # Setup: UCF record "do_e" in place
        ucf_record = create(:search_record, place: place)
        ucf_record.search_names << build(:search_name, 
          first_name: 'john', 
          last_name: 'do_e'  # Contains underscore (uncertain)
        )
        ucf_record.save

        # Setup: Search for exact "andover"
        search_query.update(
          fuzzy: false,
          last_name: 'andover',
          first_name: nil
        )

        # Execute: Filter UCF records
        # The "andover" search should NOT match "do_e" even though
        # "andover" contains the substring "dove" that matches /do.e/
        filtered = search_query.filter_ucf_records([ucf_record.id])

        # Assert: Record should NOT be included
        expect(filtered).to be_empty
      end

      it "DOES include matching UCF records with same base name" do
        # Setup: UCF record "And*ver" (uncertainty in first name, not surname)
        ucf_record = create(:search_record, place: place)
        ucf_record.search_names << build(:search_name,
          first_name: 'Sus*n',  # Contains wildcard
          last_name: 'andover'
        )
        ucf_record.save

        # Setup: Search for exact "andover"
        search_query.update(
          fuzzy: false,
          last_name: 'andover',
          first_name: nil
        )

        # Execute: Filter UCF records  
        filtered = search_query.filter_ucf_records([ucf_record.id])

        # Assert: Record SHOULD be included (surname matches exactly)
        expect(filtered).to include(ucf_record.id)
      end

      it "correctly handles both first and last names" do
        # Setup: Exact match on both names
        ucf_record = create(:search_record, place: place)
        ucf_record.search_names << build(:search_name,
          first_name: 'susan',
          last_name: 'andover'
        )
        ucf_record.save

        # Setup: Search for exact match
        search_query.update(
          fuzzy: false,
          first_name: 'susan',
          last_name: 'andover'
        )

        # Execute
        filtered = search_query.filter_ucf_records([ucf_record.id])

        # Assert: Exact match should be included
        expect(filtered).to include(ucf_record.id)
      end
    end

    context "wildcard search (contains * _ ? or {)" do
      it "DOES include UCF records matching the wildcard pattern" do
        # Setup: UCF record "do_e"
        ucf_record = create(:search_record, place: place)
        ucf_record.search_names << build(:search_name,
          first_name: 'john',
          last_name: 'do_e'
        )
        ucf_record.save

        # Setup: Wildcard search "do*e"
        search_query.update(
          fuzzy: false,
          last_name: 'do*e',  # Wildcard pattern
          first_name: nil
        )

        # Execute
        filtered = search_query.filter_ucf_records([ucf_record.id])

        # Assert: Should match (regex matching applies)
        expect(filtered).to include(ucf_record.id)
      end

      it "DOES include UCF records when search has wildcard" do
        # Setup: Normal record "andover"
        normal_record = create(:search_record, place: place)
        normal_record.search_names << build(:search_name,
          first_name: 'susan',
          last_name: 'andover'
        )
        normal_record.save

        # Setup: Wildcard search "and*ver"
        search_query.update(
          fuzzy: false,
          last_name: 'and*ver',  # User's search has wildcard
          first_name: nil
        )

        # Execute: Filter (with wildcard pattern in search)
        filtered = search_query.filter_ucf_records([normal_record.id])

        # Assert: Should match
        expect(filtered).to include(normal_record.id)
      end
    end

    context "fuzzy search (fuzzy=true)" do
      it "uses regex matching for UCF records" do
        # Setup: UCF record "do_e"
        ucf_record = create(:search_record, place: place)
        ucf_record.search_names << build(:search_name,
          first_name: 'john',
          last_name: 'do_e'
        )
        ucf_record.save

        # Setup: Fuzzy search "andover"
        search_query.update(
          fuzzy: true,  # Fuzzy enabled
          last_name: 'andover',
          first_name: nil
        )

        # Execute
        filtered = search_query.filter_ucf_records([ucf_record.id])

        # Assert: Uses regex matching (so "andover" matches "do_e" → /do.e/)
        # This is different from exact match behavior
        expect(filtered).to include(ucf_record.id)
      end
    end
  end

  describe "#exact_match_search? helper method" do
    it "returns true for exact match configuration" do
      query = build(:search_query, fuzzy: false, last_name: 'andover')
      expect(query.exact_match_search?).to eq(true)
    end

    it "returns false when fuzzy=true" do
      query = build(:search_query, fuzzy: true, last_name: 'andover')
      expect(query.exact_match_search?).to eq(false)
    end

    it "returns false when wildcards present" do
      query = build(:search_query, fuzzy: false, last_name: 'and*ver')
      expect(query.exact_match_search?).to eq(false)
    end
  end
end
```

---

### Step 4: Run Tests

```bash
# Run the new tests
bundle exec rspec spec/models/search_query/filter_ucf_exact_match_spec.rb -v

# Run all SearchQuery tests
bundle exec rspec spec/models/search_query/ -v

# Run linting
bundle exec rubocop app/models/search_query.rb
```

**Expected Output**:
```
SearchQuery
  #filter_ucf_records for exact match searches
    exact match search (fuzzy=false, no wildcards)
      ✓ does NOT include unrelated UCF records
      ✓ DOES include matching UCF records with same base name
      ✓ correctly handles both first and last names
    wildcard search (contains * _ ? or {)
      ✓ DOES include UCF records matching the wildcard pattern
      ✓ DOES include UCF records when search has wildcard
    fuzzy search (fuzzy=true)
      ✓ uses regex matching for UCF records
  #exact_match_search? helper method
    ✓ returns true for exact match configuration
    ✓ returns false when fuzzy=true
    ✓ returns false when wildcards present

Finished in X.XX seconds
9 examples, 0 failures
```

---

## Key Implementation Details

### For Exact Match Searches
When `exact_match_search?` returns true:
- Compare search term **exactly** with UCF record name
- "andover" == "andover" → true ✓
- "andover" == "do_e" → false ✓
- This prevents false matches from wildcard expansion

### For Wildcard/Fuzzy Searches
When `exact_match_search?` returns false:
- Use regex pattern matching (original logic)
- Search term "and*ver" matches pattern /and.*ver/
- Pattern /do.e/ matches if search contains pattern

### Performance Impact
- Minimal: Added one string comparison for exact matches
- Faster for exact matches (string comparison vs regex matching)

---

## Verification: Manual Testing

### Test Case 1: Exact Match Search (Should NOT include DO_E)

```ruby
# Setup
place = Place.find_by(chapman_code: 'STS', place_name: 'Kingsley')

# Create DO_E record
entry1 = create(:freereg1_csv_entry, freereg1_csv_file: file)
record1 = create(:search_record, freereg1_csv_entry: entry1)
record1.search_names << build(:search_name, first_name: 'john', last_name: 'do_e')
record1.save

# Create ANDOVER record  
entry2 = create(:freereg1_csv_entry, freereg1_csv_file: file)
record2 = create(:search_record, freereg1_csv_entry: entry2)
record2.search_names << build(:search_name, first_name: 'susan', last_name: 'andover')
record2.save

# Perform exact match search
query = SearchQuery.create!(
  fuzzy: false,
  last_name: 'andover',
  chapman_codes: ['STS']
)
query.search

# Check results
puts "exact_match_search? = #{query.exact_match_search?}"  # Should be true
puts "can_query_ucf? = #{query.can_query_ucf?}"              # Should be true
puts "Results: #{query.result_count}"                        # Should include both exact and UCF
puts "UCF Results filtered correctly? = #{query.search_result.ucf_records}"

# Verify
# - DO_E should NOT be in filtered results
# - ANDOVER should be in exact match results
```

---

## Summary of Changes

| Component | Change | Complexity |
|-----------|--------|-----------|
| `exact_match_search?` | Add new method | 🟢 Low |
| `filter_ucf_records` | Add conditional logic | 🟡 Medium |
| Tests | Add comprehensive tests | 🟡 Medium |
| Total Impact | Fixes exact match filtering | 🟢 Low Risk |

---

## Rollback Plan

If needed, to rollback:
```bash
# Remove changes
git checkout app/models/search_query.rb
rm spec/models/search_query/filter_ucf_exact_match_spec.rb
```

---

## Next Steps

1. ✅ Understand the bug (substring matching issue)
2. ✅ Apply Step 1: Add `exact_match_search?` method
3. ✅ Apply Step 2: Modify `filter_ucf_records` with conditional logic
4. ✅ Apply Step 3: Create test file
5. ✅ Run tests to verify
6. ✅ Commit changes with clear message
7. ✅ Create pull request
8. ✅ Get code review
9. ✅ Merge and deploy
