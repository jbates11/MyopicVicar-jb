# Trailing `?` Behavior Between Freereg1CsvEntry, SearchRecord, and SearchName Models

**Document Status:** Comprehensive Analysis + Issues Identified
**Date:** February 21, 2026
**Rails Version:** 5.1.7 | Ruby: 2.7.8 | MongoDB: 4.4 | Mongoid: 7.1.5

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Data Flow Architecture](#data-flow-architecture)
3. [Detailed Mechanism: How Trailing `?` Works](#detailed-mechanism)
4. [Baptism Record Example](#baptism-record-example)
5. [Scenario Analysis](#scenario-analysis)
6. [Search & Display Logic](#search--display-logic)
7. [Issues & Inconsistencies](#issues--inconsistencies)
8. [Implementation Plans](#implementation-plans)
9. [Test Coverage](#test-coverage)

---

## Executive Summary

### Current Behavior

The **trailing `?` character** in Freereg1CsvEntry name fields is **stripped during the UCF transformation process**, reducing `John?` → `John`. This happens **before** the UCF pattern expansion.

**Three-Layer Model Relationships:**

```
Freereg1CsvEntry (source of truth: original user input)
         ↓
         ↓ [Freereg1Translator.translate]
         ↓
SearchRecord.transcript_names (intermediate: hash representation)
         ↓
         ↓ [SearchRecord.transform → populate_search_from_transcript]
         ↓
SearchName (embedded in SearchRecord: searchable & displayable form)
```

### Key Issue

**Name synchronization is NOT guaranteed** across all four modification scenarios—trailing `?` information is **lost permanently** after the initial transformation from Freereg1CsvEntry.

---

## Data Flow Architecture

### Layer 1: Freereg1CsvEntry Model

**File:** [app/models/freereg1_csv_entry.rb](../app/models/freereg1_csv_entry.rb)

**Relevant Fields for Baptism:**
- `person_forename` - Baptized person's first name (e.g., `"Mary?"`)
- `person_surname` - Baptized person's last name (e.g., `"Smith?"`)
- `father_forename` - Father's first name
- `father_surname` - Father's last name
- `mother_forename` - Mother's first name
- `mother_surname` - Mother's last name
- `multiple_witnesses.*` - Embedded witness names

**Constraints:**
- Stores the **raw, user-entered data** as strings
- Surnames are capitalized via `captitalize_surnames` callback (line 267)
- Accepts nested attributes for `multiple_witnesses`

**State Transitions:**
```
User Input → Freereg1CsvEntry Fields → [before_save callbacks]
           ↓
         1. sanitize_fields
         2. add_digest (MD5 of key fields)
         3. captitalize_surnames (UPCASE surnames only)
         4. check_register_type
```

### Layer 2: SearchRecord Model

**File:** [app/models/search_record.rb](../app/models/search_record.rb)

**Key Fields:**
- `transcript_names` (Array of Hash) - Intermediate representation before SearchName embedding
  - Each hash: `{role: 'ba', type: 'primary', first_name: 'Mary', last_name: 'Smith', ...}`
  - **Note:** Trailing `?` is **already removed** at this stage
- `search_names` (embedded Array of SearchName) - Final searchable names

**Data Population Path:**

| Step | Method | Line | Action |
|------|--------|------|--------|
| 1 | `SearchRecord.update_create_search_record(entry, ...)` | 586 | Create new SearchRecord from entry |
| 2 | `Freereg1Translator.translate(file, entry)` | ~40 | Extract names to transcript_names hash |
| 3 | `SearchRecord.new(search_record_parameters)` | 598 | Initialize with transcript_names |
| 4 | `record.transform()` | 1217 | Orchestrate transformation pipeline |
| 5a | `populate_search_from_transcript()` | 1036 | Clear & rebuild search_names |
| 5b | `downcase_all()` | 759 | Convert names to lowercase |
| 5c | `separate_all()` | ? | Split hyphenated names |
| 5d | `emend_all()` | ? | Apply user-provided corrections |
| 5e | `transform_ucf()` | 1298 | **Expand UCF patterns** (AFTER trailing `?` stripped) |
| 5f | `create_soundex()` | 928 | Generate phonetic variant |

### Layer 3: SearchName Model (Embedded)

**File:** [app/models/search_name.rb](../app/models/search_name.rb)

**Fields:**
```ruby
field :first_name,  type: String
field :last_name,   type: String
field :origin,      type: String          # Values: 'transcript', 'ucf', 'emendation'
field :role,        type: String          # Values: 'ba', 'f', 'm', 'wt' (baptism roles)
field :type,        type: String          # Values: 'primary', 'family', 'witness'
field :gender,      type: String          # Values: 'm', 'f', nil
```

**Embedded In:**
```ruby
# SearchRecord model:
embeds_many :search_names, :class_name => 'SearchName'
```

**Constraint:** SearchName is **embedded**, not referenced—no separate collection

---

## Detailed Mechanism: How Trailing `?` Works

### The Trailing `?` Lifecycle

#### Step 1: User Enters Data in Freereg1CsvEntry

User submits edit form with:
```
person_forename: "Mary?"
person_surname: "Smith?"
```

These values are **stored as-is** in Freereg1CsvEntry fields.

#### Step 2: Edit Controller Triggers SearchRecord Creation

**File:** [app/controllers/freereg1_csv_entries_controller.rb](../app/controllers/freereg1_csv_entries_controller.rb)

**Update Action Flow:**
```ruby
# Line ~309: update action
def update
  entry = Freereg1CsvEntry.find(params[:id])
  entry.update_attributes(freereg1_csv_entry_params)
  
  # Post-update hooks:
  entry.check_and_correct_county
  entry.check_year
  entry.update_place_ucf_list  # <-- CRITICAL: Updates SearchRecord
end
```

**Critical Hook:** `update_place_ucf_list` (in Freereg1CsvEntry)
```ruby
# Called after entry is saved
# Triggers SearchRecord recreation via:
SearchRecord.update_create_search_record(entry, search_version, place)
```

#### Step 3: Freereg1Translator Extracts Names

**File:** [lib/freereg1_translator.rb](../lib/freereg1_translator.rb)

**For Baptisms (line 144-234):**
```ruby
def self.translate_names_baptism(entry)
  names = []
  
  # Case: person has a surname
  case
  when entry.person_surname.present?
    names << {
      role: 'ba',
      type: 'primary',
      first_name: entry.person_forename||"",      # "Mary?" ← STILL HAS TRAILING ?
      last_name: entry.person_surname              # "SMITH?" ← STILL HAS TRAILING ?
    }
  # Other cases...
  end
  
  # Father
  if entry.father_forename
    names << {
      role: 'f',
      type: 'other',
      first_name: entry.father_forename,
      last_name: entry.father_surname
    }
  end
  
  # Mother
  if entry.mother_forename
    names << {
      role: 'm',
      type: 'other',
      first_name: entry.mother_forename,
      last_name: entry.mother_surname.present? ? entry.mother_surname : entry.father_surname
    }
  end
  
  # Witnesses
  entry.multiple_witnesses.each do |witness|
    names << {
      role: 'wt',
      type: 'witness',
      first_name: witness.witness_forename,
      last_name: witness.witness_surname
    }
  end
  
  names
end
```

**At This Point:**
- Names still have trailing `?`: `{first_name: "Mary?", last_name: "SMITH?"}`
- Stored in **transcript_names** field of new SearchRecord

#### Step 4: SearchRecord.transform() Pipeline

**File:** [app/models/search_record.rb](../app/models/search_record.rb), Line 1217

```ruby
def transform
  populate_search_from_transcript     # Step 4a: Create SearchName objects
  downcase_all                        # Step 4b: Lowercase all names
  separate_all                        # Step 4c: Split hyphenated
  emend_all                           # Step 4d: Apply emendations
  transform_ucf                       # Step 4e: EXPAND UCF (strips ?)
  create_soundex                      # Step 4f: Create phonetic variants
  transform_date                      # Step 4g: Parse dates
  populate_location                   # Step 4h: Extract location
end
```

#### Step 4a: populate_search_from_transcript()

**File:** [app/models/search_record.rb](../app/models/search_record.rb), Line 1036-1072

```ruby
def populate_search_from_transcript
  search_names.clear
  search_soundex.clear
  populate_search_names
end

def populate_search_names
  return unless transcript_names && transcript_names.size > 0
  
  transcript_names.each do |name_hash|
    # name_hash: {role: 'ba', type: 'primary', first_name: 'Mary?', last_name: 'SMITH?'}
    
    person_type = PersonType::PRIMARY  # if name_hash[:type] == 'primary'
    person_role = name_hash[:role]     # 'ba'
    person_gender = gender_from_role(person_role)
    
    # CREATE SEARCH NAME OBJECT (streaming SearchName.new)
    name = search_name(
      name_hash[:first_name],   # "Mary?" ← STILL HAS TRAILING ?
      name_hash[:last_name],    # "SMITH?"
      person_type,
      person_role,
      person_gender
    )
    
    if name
      search_names << name  # Embedded into SearchRecord
    end
  end
end

def search_name(first_name, last_name, person_type, person_role, person_gender, source = Source::TRANSCRIPT)
  name = nil
  unless last_name.blank?
    name = SearchName.new({
      :first_name => copy_name(first_name),  # "Mary?" (copied)
      :last_name => copy_name(last_name),    # "SMITH?" (copied)
      :origin => source,                     # 'transcript'
      :type => person_type,                  # 'primary'
      :role => person_role,                  # 'ba'
      :gender => person_gender               # 'm', 'f', or nil
    })
  end
  name
end
```

**At This Point:**
- SearchName.first_name = `"Mary?"` with origin = `'transcript'`
- SearchName.last_name = `"SMITH?"` with origin = `'transcript'`

#### Step 4b: downcase_all()

**File:** [app/models/search_record.rb](../app/models/search_record.rb), Line 759

```ruby
def downcase_all
  search_names.each do |name|
    name[:first_name].downcase! if name[:first_name]  # "Mary?" → "mary?"
    name[:last_name].downcase! if name[:last_name]    # "SMITH?" → "smith?"
  end
end
```

**At This Point:**
- SearchName.first_name = `"mary?"`
- SearchName.last_name = `"smith?"`
- Trailing `?` still present

#### Step 4e: transform_ucf() - THE CRITICAL STEP

**File:** [lib/ucf_transformer.rb](../lib/ucf_transformer.rb), Line 56-67

```ruby
def self.transform(name_array)
  transformed_names = []
  
  name_array.each do |name|
    if name.first_name
      # ▼ STRIPS TRAILING ? USING REGEX SUBSTITUTION
      name.first_name.sub!(QUESTION_MARK_UCF, '\1')
      #                     /(\w*?)\?/
      # Captures all word chars (group 1) before ?, replaces with group 1
      # "mary?" → "mary"
      
      expanded_forenames = expand_single_name(name.first_name)
      if expanded_forenames  # Only if UCF expansion happened
        transformed_names = expanded_forenames.map { |forename|
          SearchName.new(name.attributes.merge({
            :first_name => forename,
            :origin => 'ucf'
          }))
        }
      end
    end
    
    if name.last_name
      # ▼ STRIPS TRAILING ? FROM LAST NAME TOO
      name.last_name.sub!(QUESTION_MARK_UCF, '\1')
      # "smith?" → "smith"
      
      expanded_surnames = expand_single_name(name.last_name)
      if expanded_surnames  # Only if UCF expansion happened
        transformed_names += expanded_surnames.map { |surname|
          SearchName.new(name.attributes.merge({
            :last_name => surname,
            :origin => 'ucf'
          }))
        }
      end
    end
  end
  
  # RESULT: Original name_array + transformed UCF expansions
  name_array + transformed_names
end
```

**CRITICAL BEHAVIOR:**

| Input | Regex Operation | Output | Issue |
|-------|-----------------|--------|-------|
| `"mary?"` | `.sub!(/(\w*?)\?/, '\1')` | `"mary"` | ✗ Trailing `?` stripped |
| `"mary"` | `.sub!(/(\w*?)\?/, '\1')` | `"mary"` | ✓ No change (no `?`) |
| `"M{1,2}ary?"` | `.sub!(/(\w*?)\?/, '\1')` | `"M{1,2}ary"` | ✓ Brackets kept, `?` stripped |
| `"M[ar]y?"` | `.sub!(/(\w*?)\?/, '\1')` | `"M[ar]y"` | ✓ Brackets kept, `?` stripped |

**Result After transform_ucf():**
- Original SearchName with `origin: 'transcript'` has `?` removed
- New SearchName objects with `origin: 'ucf'` are created from bracket expansions

### Result: Final SearchRecord State

After `SearchRecord.transform()` completes:

```javascript
search_record.search_names = [
  // Original from transcript (question mark stripped):
  {
    first_name: "mary",      // ← Trailing ? REMOVED
    last_name: "smith",
    origin: "transcript",
    type: "primary",
    role: "ba",
    gender: nil
  },
  // If UCF expansions happened (e.g., M[ar]y → Mary, Mary):
  {
    first_name: "Mary",
    last_name: "mary",
    origin: "ucf",
    type: "primary",
    role: "ba"
  },
  {
    first_name: "Mary",
    last_name: "aary",
    origin: "ucf",
    type: "primary",
    role: "ba"
  }
]

search_record.transcript_names = [
  // PRESERVED AS ENTERED (question mark KEPT):
  {
    first_name: "Mary?",     // ← Original input preserved
    last_name: "SMITH?",
    type: "primary",
    role: "ba"
  }
  // ... father, mother, witnesses
]
```

---

## Baptism Record Example

### Scenario: Complete Baptism Record

**User Input into Freereg1CsvEntry:**
```
person_forename: "Mary?"
person_surname: "Smith?"
father_forename: "John"
father_surname: "Smith"
mother_forename: "Anne?"
mother_surname: "Jones"
witness1_forename: "Thomas?"
witness1_surname: "Brown?"
```

### Step 1: Freereg1CsvEntry Storage

| Field | Value | Storage |
|-------|-------|---------|
| person_forename | `"Mary?"` | As-is (string) |
| person_surname | `"Smith?"` | Capitalized: `"SMITH?"` |
| father_forename | `"John"` | As-is |
| father_surname | `"Smith"` | Capitalized: `"SMITH"` |
| mother_forename | `"Anne?"` | As-is |
| mother_surname | `"Jones"` | Capitalized: `"JONES"` |
| witness1_forename | `"Thomas?"` | Embedded in multiple_witnesses |
| witness1_surname | `"Brown?"` | Embedded, capitalized: `"BROWN?"` |

**Digest Calculation:**
- Surname capitalization happens **before** digest
- Digest includes: location, soundex, search_names, dates
- Digest = MD5 of concatenated string

### Step 2: Freereg1Translator Output (transcript_names)

```ruby
[
  {role: 'ba', type: 'primary', first_name: 'Mary?', last_name: 'SMITH?'},  # Baptized person
  {role: 'f', type: 'other', first_name: 'John', last_name: 'SMITH'},       # Father
  {role: 'm', type: 'other', first_name: 'Anne?', last_name: 'JONES'},      # Mother
  {role: 'wt', type: 'witness', first_name: 'Thomas?', last_name: 'BROWN?'} # Witness
]
```

### Step 3: SearchRecord.transform() Pipeline

#### After downcase_all():
```ruby
search_names = [
  {first_name: 'mary?', last_name: 'smith?', origin: 'transcript', ...},
  {first_name: 'john', last_name: 'smith', origin: 'transcript', ...},
  {first_name: 'anne?', last_name: 'jones', origin: 'transcript', ...},
  {first_name: 'thomas?', last_name: 'brown?', origin: 'transcript', ...}
]
```

#### After transform_ucf() [CRITICAL]:
```ruby
search_names = [
  # Original (question mark STRIPPED by regex):
  {first_name: 'mary', last_name: 'smith', origin: 'transcript', ...},
  {first_name: 'john', last_name: 'smith', origin: 'transcript', ...},
  {first_name: 'anne', last_name: 'jones', origin: 'transcript', ...},
  {first_name: 'thomas', last_name: 'brown', origin: 'transcript', ...},
  
  # New SearchName objects (if UCF expansion occurred, e.g., [ar] → a, r):
  # (None in this example - no brackets, just question marks removed)
]
```

### Final SearchRecord State

```javascript
{
  _id: ObjectId(...),
  freereg1_csv_entry_id: ObjectId(...),
  record_type: 'ba',
  transcript_names: [
    {first_name: 'Mary?', last_name: 'SMITH?', type: 'primary', role: 'ba'},
    {first_name: 'John', last_name: 'SMITH', type: 'other', role: 'f'},
    {first_name: 'Anne?', last_name: 'JONES', type: 'other', role: 'm'},
    {first_name: 'Thomas?', last_name: 'BROWN?', type: 'witness', role: 'wt'}
  ],
  search_names: [
    {first_name: 'mary', last_name: 'smith', origin: 'transcript', type: 'primary', role: 'ba', ...},
    {first_name: 'john', last_name: 'smith', origin: 'transcript', type: 'other', role: 'f', ...},
    {first_name: 'anne', last_name: 'jones', origin: 'transcript', type: 'other', role: 'm', ...},
    {first_name: 'thomas', last_name: 'brown', origin: 'transcript', type: 'witness', role: 'wt', ...}
  ],
  search_soundex: [
    {first_name: 'M600', last_name: 'S500', ...},  // Soundex of 'mary smith'
    {first_name: 'J500', last_name: 'S500', ...},
    {first_name: 'A500', last_name: 'J520', ...},
    {first_name: 'T520', last_name: 'B600', ...}
  ]
}
```

---

## Scenario Analysis

### Scenario 1: Entry With No UCF, Modify With No UCF

**Initial State:**
```
Freereg1CsvEntry.person_forename: "Mary"      (no ?)
Freereg1CsvEntry.person_surname: "Smith"      (no ?)

SearchRecord.transcript_names[0]:
  {first_name: "Mary", last_name: "Smith", ...}

SearchName (in search_names):
  {first_name: "mary", last_name: "smith", origin: "transcript", ...}
```

**User Action:** Edit and save `person_forename: "Mary?"` (adds trailing ?)

**State Transition:**

| Step | Component | Value | Status |
|------|-----------|-------|--------|
| 1 | Freereg1CsvEntry.person_forename | `"Mary?"` | ✓ Stored |
| 2 | Freereg1Translator.translate | `{first_name: "Mary?", ...}` | ✓ Built |
| 3 | SearchRecord.transcript_names[0] | `{first_name: "Mary?", ...}` | ✓ Updated |
| 4 | transform_ucf() strips ? | `{first_name: "Mary", ...}` | ✗ Lost |
| 5 | SearchName.first_name | `"mary"` | ✗ Missing ? |

**Synchronization Status:** ❌ **NOT SYNCHRONIZED**

```
Freereg1CsvEntry     SearchRecord.transcript_names    SearchName
    "Mary?"    →           "Mary?"           →         "mary"
                                               (? removed)
```

**Call Sequence:**

```
User clicks "Save"
    ↓
Freereg1CsvEntriesController#update
    ↓
entry.update_attributes({person_forename: "Mary?"})
    ↓
[before_save callback] captitalize_surnames
    • Skips forenames
    ↓
entry.save ✓
    ↓
[after_update callback] update_place_ucf_list
    ↓
SearchRecord.update_create_search_record(entry, search_version, place)
  · Freereg1Translator.translate(entry.freereg1_csv_file, entry)
    · translate_names_baptism(entry)
    · Extracts: {first_name: "Mary?", ...}
  · SearchRecord.new(search_record_parameters)
    · searchrecord.transcript_names = [{first_name: "Mary?", ...}]
  · search_record.transform()
    · populate_search_from_transcript()
      · populate_search_names()
      · Creates SearchName with {first_name: "Mary?", ...}
    · downcase_all()
      · "Mary?" → "mary?"
    · transform_ucf()
      · STRIPS TRAILING ?
      · name.first_name.sub!(/(\w*?)\?/, '\1')
      · "mary?" → "mary"
    · create_soundex()
      · Soundex of "mary"
  · search_record.digest = new_search_record.cal_digest
  · old_search_record.destroy
  · new_search_record.save
```

**Code Execution Path:**

**File:** [app/models/search_record.rb](../app/models/search_record.rb#L586)
```ruby
def self.update_create_search_record(entry, search_version, place)
  search_record_parameters = Freereg1Translator.translate(entry.freereg1_csv_file, entry)
  # transcript_names now includes "Mary?"
  
  new_search_record = SearchRecord.new(search_record_parameters)
  new_search_record.transform  # Line 601: Strips ?
  new_search_record.save
  
  search_record.destroy  # Old record discarded
end
```

**File:** [lib/freereg1_translator.rb](../lib/freereg1_translator.rb#L184)
```ruby
def self.translate_names_baptism(entry)
  names = []
  case
  when entry.person_surname.present?
    names << {
      role: 'ba',
      type: 'primary',
      first_name: entry.person_forename || "",  # "Mary?"
      last_name: entry.person_surname            # "SMITH"
    }
  end
  names
end
```

---

### Scenario 2: Entry With No UCF, Modify With UCF

**Initial State:**
```
Freereg1CsvEntry.person_forename: "Mary"      (no ?)
SearchName.first_name: "mary"
```

**User Action:** Edit and save `person_forename: "M{1,2}ary"` (UCF range, no ?)

**State Transition:**

| Step | Component | Value | Status |
|------|-----------|-------|--------|
| 1 | Freereg1CsvEntry.person_forename | `"M{1,2}ary"` | ✓ Stored |
| 2 | transcript_names[0].first_name | `"M{1,2}ary"` | ✓ Built |
| 3 | downcase_all() | `"m{1,2}ary"` | ✓ Lowercased |
| 4 | transform_ucf() expands | `"mary"`, `"maary"` | ✓ Expanded |
| 5 | search_names | `[{fn: "mary", origin: "transcript"}, {fn: "mary", origin: "ucf"}, {fn: "maary", origin: "ucf"}]` | ✓ Multiple |

**Synchronization Status:** ✓ **SYNCHRONIZED**

```
Freereg1CsvEntry          SearchRecord.transcript_names       SearchName(s)
  "M{1,2}ary"    →              "M{1,2}ary"         →    "mary" (original)
                                                          "mary" (ucf)
                                                          "maary" (ucf)
```

**Code Path:**

```
transform_ucf() at line 57:
  QUESTION_MARK_UCF = /(\w*?)\?/
  name.first_name.sub!(/(\w*?)\?/, '\1')
  "m{1,2}ary".sub!(/(\w*?)\?/, '\1') → "m{1,2}ary" (NO CHANGE - no ?)
  
  expand_single_name("m{1,2}ary")
    → ["mary", "maary"]  (range {} expanded)
  
  Creates NEW SearchName objects:
    {first_name: "mary", origin: "ucf", ...}
    {first_name: "maary", origin: "ucf", ...}
```

---

### Scenario 3: Entry With UCF, Modify Without UCF

**Initial State:**
```
Freereg1CsvEntry.person_forename: "M_ry"      (single-char wildcard)
SearchRecord.search_names:
  [{fn: "mry", origin: "transcript"},
   {fn: "mary", origin: "ucf"},
   {fn: "mbry", origin: "ucf"},
   ...]
```

**User Action:** Edit and save `person_forename: "Mary?"` (plain name with ?)

**State Transition:**

| Step | Component | Value | Status |
|------|-----------|-------|--------|
| 1 | Freereg1CsvEntry.person_forename | `"Mary?"` | ✓ Stored |
| 2 | transcript_names[0].first_name | `"Mary?"` | ✓ Built |
| 3 | downcase_all() | `"mary?"` | ✓ Lowercased |
| 4 | transform_ucf() strips ? | `"mary"` | ✓ Stripped |
| 5 | search_names | `[{fn: "mary", origin: "transcript"}]` | ✗ Extensions lost |

**Synchronization Status:** ❌ **NOT SYNCHRONIZED** (UCF variants lost)

```
Freereg1CsvEntry          SearchRecord.transcript_names       SearchName(s)
Before: "M_ry"              "M_ry"                    [ucf variants]
After:  "Mary?"    →         "Mary?"         →         "mary"
                                             (only transcript, no ucf variants)
```

**Issue:** The UCF wildcard variants (`mary`, `mbry`, etc.) are completely replaced because:
1. Old SearchRecord is destroyed
2. New SearchRecord is created with only transcript names
3. `transform_ucf()` on "Mary?" produces only "mary" (no brackets to expand)

---

### Scenario 4: Entry With UCF, Modify With Different UCF

**Initial State:**
```
Freereg1CsvEntry.person_forename: "M[ar]y"    (bracket alternative)
SearchRecord.search_names:
  [{fn: "m[ar]y", origin: "transcript"},
   {fn: "may", origin: "ucf"},
   {fn: "mary", origin: "ucf"}]
```

**User Action:** Edit and save `person_forename: "Ma*y"` (multi-char wildcard)

**State Transition:**

| Step | Component | Value | Status |
|------|-----------|-------|--------|
| 1 | Freereg1CsvEntry.person_forename | `"Ma*y"` | ✓ Stored |
| 2 | transcript_names[0].first_name | `"Ma*y"` | ✓ Built |
| 3 | downcase_all() | `"ma*y"` | ✓ Lowercased |
| 4 | transform_ucf() expands | `"maXy", "maXXy", ...` | ✓ Expanded |
| 5 | search_names | `[{fn: "ma*y", origin: "transcript"}, {fn: "maXy"...}, ...]` | ✓ New variants |

**Synchronization Status:** ✓ **SYNCHRONIZED** (but variants changed)

```
Before: "M[ar]y"  → [may, mary]
After:  "Ma*y"    → [maXy, maXXy, ...]  (completely new wildcard expansions)
```

---

## Search & Display Logic

### How Search Works

**File:** [app/controllers/search_queries_controller.rb](../app/controllers/search_queries_controller.rb)

**Search Query Flow:**

```
User submits search: "Mary"
    ↓
SearchQueriesController#create
    ↓
Parses search parameters
    ↓
Builds MongoDB query:
    {
      record_type: "ba",
      "search_names.last_name": "smith",
      "search_names.first_name": "mary"
    }
    ↓
SearchRecord.where(query).hints(index)
    ↓
Uses compound index: 'ln_fn_rt_ssd'
    [search_names.last_name, search_names.first_name, record_type, search_date]
```

**Field Used in Search:** `search_names` (NOT `transcript_names`)

| Scenario | Search Input | Matches | Result |
|----------|--------------|---------|--------|
| Scenario 1 | "mary" | `search_names[0]` | ✓ Found (? stripped) |
| Scenario 1 | "mary?" | No match | ✗ Not found (? not in search_names) |
| Scenario 2 | "mary" | `search_names[0]`, `search_names[1]` | ✓ Found (both ucf and transcript) |
| Scenario 2 | "maary" | `search_names[2]` | ✓ Found (ucf variant) |
| Scenario 3 | "mary" | `search_names[0]` | ✓ Found |
| Scenario 3 | "mbry" | No match | ✗ Not found (old ucf variants deleted) |
| Scenario 4 | "mayy" | Depends on regex | ? Fuzzy (wildcard expansion behavior) |

### How Display Works

**File:** [app/views/search_queries/_display_freereg_search_record_desktop.html.erb](../app/views/search_queries/_display_freereg_search_record_desktop.html.erb)

**Display Logic:**

```erb
<!-- Display the record -->
<% search_record = result %>

<!-- PRIMARY NAME DISPLAY -->
<% search_record[:transcript_names].uniq.each_with_index do |name, i| %>
  <% if name['type'] == 'primary' %>
    <%= "#{name['first_name']} #{name['last_name']}" %>
  <% end %>
<% end %>
```

**Displayed Names Use:** `transcript_names` (NOT `search_names`)

| Scenario | Displayed Name | Includes ` Original (with ?) |
|----------|---|---|
| Scenario 1 | "Mary? Smith?" | ✓ YES |
| Scenario 2 | "M{1,2}ary Smith" | ✓ YES (UCF brackets shown) |
| Scenario 3 | "Mary? Smith?" | ✓ YES |
| Scenario 4 | "Ma*y Smith" | ✓ YES (new wildcard shown) |

---

## Issues & Inconsistencies

### Issue #1: Name Synchronization Across Scenarios

**Problem:** Trailing `?` information is stripped from `search_names` during `transform_ucf()`, but retained in `transcript_names`. This creates an asymmetry:

```
Freereg1CsvEntry.person_forename     SearchRecord.transcript_names    SearchRecord.search_names
        ↓                                       ↓                                ↓
     "Mary?"                            "Mary?"                          "mary"
     
     ✓ Consistent                       ✓ Consistent                     ✗ Information LOST
```

**Impact:**
- Search for "Mary?" fails (search uses `search_names`)
- Display shows "Mary?" (display uses `transcript_names`)
- User sees "Mary?" but cannot search for "Mary?"

**Affected Scenarios:** All 4 scenarios shown above

**Root Cause:** [lib/ucf_transformer.rb](../lib/ucf_transformer.rb), Line 57 & 67

```ruby
name.first_name.sub!(QUESTION_MARK_UCF, '\1')  # Strips ? from ORIGINAL transcript name
# This mutates the SearchName object IN PLACE
```

### Issue #2: Permanent Loss of Question Mark Information

**Problem:** Once `transform_ucf()` strips the trailing `?`, it cannot be recovered because:
1. The original Freereg1CsvEntry is never examined during search
2. The SearchRecord is reconstructed on each edit (old record destroyed)
3. The stripped `?` is not stored anywhere else

**Example:**

```
Time 0: User enters "Mary?" → Stored in Freereg1CsvEntry ✓
Time 1: SearchRecord created → transcript_names = "Mary?" ✓
Time 2: transform_ucf() → search_names = "mary" ✗ (? lost)
Time 3: User edits to "Mary" → New SearchRecord created
        Old SearchRecord destroyed → All history lost ✗
Time 4: No way to know original entry had "Mary?" ✗
```

**Affected Operations:**
- Any modification to the entry triggers SearchRecord recreation
- Old search variants are lost (Scenario 3)
- No audit trail of `?` changes

### Issue #3: Inconsistent UCF Expansion for Trailing `?`

**Problem:** The trailing `?` is treated as a **non-UCF character** even though it may indicate **uncertainty about a character**:

```
User Intent: "Mary?" = "uncertain about one character"
Code Behavior: "Mary?" = strip ? and treat as plain "Mary"
Expected Behavior: "Mary?" = expand to M?ry (any character) OR keep ? in search
```

**Comparison with Other UCF:**

| Input | Current Behavior | Expected Behavior | Issue |
|-------|-----------------|------------------|-------|
| `M_ry` | Expand to `Mary`, `Mbry`, ... | ✓ Correct | - |
| `M[ar]y` | Expand to `Mary`, `Mary` | ✓ Correct (buggy input) | - |
| `M*y` | Expand to `Mary`, `MyXy`, ... | ✓ Correct | - |
| `Mary?` | Strip to `Mary` | ✗ Should expand like `_` OR preserve? | **BUG** |

**In UCF_TRANSFORMER:**

```ruby
QUESTION_MARK_UCF = /(\w*?)\?/
# Definition: Match word characters (greedy), followed by ?
# Replacement: Keep only the word characters

# This treats ? as "remove me", not "uncertain character"
```

### Issue #4: Display Missing Question Mark in Names with Wildcard UCF

**When:** User enters "Mary?" (plain with trailing ?)

**Current Display:**
```
Displayed name: "Mary?" ✓ (from transcript_names)
```

**When:** User enters "M_ry?" (wildcard + trailing ?)

**Current Display:**
```
Input:  "M_ry?"
transcript_names after translator: "M_ry?" ✓
After downcase_all: "m_ry?"
After transform_ucf: strips ? → "m_ry"
Expanded: "mary", "mbry", ...
Displayed name in search_names: "mary" ✗ (no ?)

But transcript_names still has: "M_ry?" ✓
PROBLEM: Display shows "M_ry?" but search_names has variants WITHOUT ?
```

---

## Implementation Plans

### Plan A: Preserve Trailing `?` in SearchName (RECOMMENDED)

**Objective:** Keep the trailing `?` indicator throughout the pipeline

**Changes Required:**

#### 1. Modify UcfTransformer to NOT strip trailing `?`

**File:** [lib/ucf_transformer.rb](../lib/ucf_transformer.rb)

**Current Code (Lines 56-67):**
```ruby
def self.transform(name_array)
  transformed_names = []
  name_array.each do |name|
    if name.first_name
      name.first_name.sub!(QUESTION_MARK_UCF, '\1')  # ← REMOVE THIS LINE
      expanded_forenames = expand_single_name(name.first_name)
      # ...
    end
    # ...
  end
end
```

**Replacement:**
```ruby
def self.transform(name_array)
  transformed_names = []
  
  name_array.each do |name|
    # Track whether original names had trailing ?
    original_first_name = name.first_name
    original_last_name = name.last_name
    has_first_name_uncertainty = original_first_name&.end_with?('?')
    has_last_name_uncertainty = original_last_name&.end_with?('?')
    
    if name.first_name
      # CHANGE: Remove the .sub! that strips ?
      # Only strip ? for UCF expansion purposes, NOT from original name
      name_without_question = name.first_name.sub(QUESTION_MARK_UCF, '\1')  # temp copy
      
      expanded_forenames = expand_single_name(name_without_question)
      if expanded_forenames
        expanded_forenames.each do |forename|
          # Add ? back if original had it
          forename_with_uncertainty = has_first_name_uncertainty ? "#{forename}?" : forename
          transformed_names << SearchName.new(
            name.attributes.merge({
              :first_name => forename_with_uncertainty,
              :origin => 'ucf'
            })
          )
        end
      end
    end
    
    if name.last_name
      name_without_question = name.last_name.sub(QUESTION_MARK_UCF, '\1')  # temp copy
      
      expanded_surnames = expand_single_name(name_without_question)
      if expanded_surnames
        expanded_surnames.each do |surname|
          surname_with_uncertainty = has_last_name_uncertainty ? "#{surname}?" : surname
          transformed_names += SearchName.new(
            name.attributes.merge({
              :last_name => surname_with_uncertainty,
              :origin => 'ucf'
            })
          )
        end
      end
    end
  end
  
  # Original names are kept with ? intact
  # New UCF expansions get ? appended if needed
  name_array + transformed_names
end
```

#### 2. Modify Search Logic to Handle `?` Interpretation

**File:** [app/models/search_record.rb](../app/models/search_record.rb)

**Add Search Method:**
```ruby
def self.search_with_uncertainty_handling(search_params)
  # If user searches for "Mary", match both "Mary" AND "Mary?"
  # If user searches for "Mary?", match only "Mary?"
  
  modified_params = search_params.dup
  
  # Expand search names to include uncertainty variants
  first_name = search_params[:first_name]
  last_name = search_params[:last_name]
  
  if first_name.present? && !first_name.end_with?('?')
    # User didn't specify uncertainty, so match both modes
    modified_params[:first_name] = { '$in' => [first_name, "#{first_name}?"] }
  end
  
  if last_name.present? && !last_name.end_with?('?')
    modified_params[:last_name] = { '$in' => [last_name, "#{last_name}?"] }
  end
  
  where(modified_params)
end
```

#### 3. Add Migration (Not needed for MongoDB)

Since this is MongoDB with Mongoid, no schema migration required. The new field values are backward compatible.

#### 4. Add Tests

**File:** [spec/models/ucf_transformer_spec.rb](../spec/models/ucf_transformer_spec.rb) (create if needed)

```ruby
RSpec.describe UcfTransformer do
  describe '.transform' do
    describe 'preserving trailing question mark' do
      it 'keeps trailing ? in original name when no UCF' do
        name_array = [
          SearchName.new({
            first_name: 'Mary?',
            last_name: 'Smith?',
            origin: 'transcript'
          })
        ]
        
        result = UcfTransformer.transform(name_array)
        
        # Original should still have ?
        expect(result[0].first_name).to eq('Mary?')
        expect(result[0].last_name).to eq('Smith?')
        # No UCF variants created
        expect(result.size).to eq(1)
      end
      
      it 'preserves ? when expanding UCF brackets' do
        name_array = [
          SearchName.new({
            first_name: 'M[ar]y?',
            last_name: 'Smith'
          })
        ]
        
        result = UcfTransformer.transform(name_array)
        
        # Original unchanged
        expect(result[0].first_name).to eq('M[ar]y?')
        
        # UCF variants should also have ?
        ucf_names = result.select { |n| n.origin == 'ucf' }
        expect(ucf_names.map(&:first_name)).to match_array(['May?', 'Mary?'])
      end
    end
  end
end
```

---

### Plan B: Store Trailing `?` Metadata Separately

**Objective:** Track uncertainty separately from name values

**Changes Required:**

#### 1. Modify SearchName Model

**File:** [app/models/search_name.rb](../app/models/search_name.rb)

```ruby
class SearchName
  include Mongoid::Document
  
  field :first_name,           type: String
  field :last_name,            type: String
  field :origin,               type: String
  field :role,                 type: String
  field :gender,               type: String
  field :type,                 type: String
  
  # NEW FIELDS TO TRACK UNCERTAINTY
  field :first_name_uncertain, type: Boolean, default: false  # Was first_name "...?"
  field :last_name_uncertain,  type: Boolean, default: false  # Was last_name "...?"
  
  embedded_in :search_record
  
  # Helper method for display
  def display_name
    fn = first_name.presence || ""
    ln = last_name.presence || ""
    fn = "#{fn}?" if first_name_uncertain
    ln = "#{ln}?" if last_name_uncertain
    "#{fn} #{ln}".strip
  end
end
```

#### 2. Modify UcfTransformer

```ruby
def self.transform(name_array)
  transformed_names = []
  
  name_array.each do |name|
    # Detect and track uncertainty BEFORE stripping
    has_first_question = name.first_name&.end_with?('?')
    has_last_question = name.last_name&.end_with?('?')
    
    # Strip ? for UCF processing
    name.first_name = name.first_name.sub(QUESTION_MARK_UCF, '\1') if name.first_name
    name.last_name = name.last_name.sub(QUESTION_MARK_UCF, '\1') if name.last_name
    
    # Mark original name with uncertainty flag
    name.first_name_uncertain = has_first_question
    name.last_name_uncertain = has_last_question
    
    # Process UCF (no ? to interfere)
    # ...
  end
end
```

#### 3. Modify Display View

**File:** [app/views/search_queries/_display_freereg_search_record_desktop.html.erb](../app/views/search_queries/_display_freereg_search_record_desktop.html.erb)

```erb
<% search_record[:search_names].uniq.each_with_index do |name, i| %>
  <% if name['type'] == 'primary' %>
    <% fn = name['first_name'].presence || "" %>
    <% ln = name['last_name'].presence || "" %>
    <% fn = "#{fn}?" if name['first_name_uncertain'] %>
    <% ln = "#{ln}?" if name['last_name_uncertain'] %>
    <%= "#{fn} #{ln}".strip %>
  <% end %>
<% end %>
```

**Pros:**
- Clean separation of concerns
- Name values remain lowercase
- Easy to toggle display with/without `?`
- Backward compatible

**Cons:**
- Requires schema (boolean fields)
- Modifies SearchName model
- More database storage

---

### Plan C: Store Original Freereg1CsvEntry Values in SearchRecord

**Objective:** Maintain a reference to original user input

**Changes Required:**

#### 1. Add Fields to SearchRecord

**File:** [app/models/search_record.rb](../app/models/search_record.rb)

```ruby
class SearchRecord
  # ... existing fields ...
  
  # NEW: Store original names from Freereg1CsvEntry
  field :original_transcript_names, type: Array, default: []
  # Format: [
  #   {first_name: 'Mary?', last_name: 'SMITH?', role: 'ba', ...},
  #   ...
  # ]
end
```

#### 2. Populate in update_create_search_record

```ruby
def self.update_create_search_record(entry, search_version, place)
  search_record_parameters = Freereg1Translator.translate(entry.freereg1_csv_file, entry)
  
  new_search_record = SearchRecord.new(search_record_parameters)
  
  # STORE ORIGINAL NAMES BEFORE TRANSFORMATION
  new_search_record.original_transcript_names = new_search_record.transcript_names.deep_dup
  
  new_search_record.transform
  # ... rest of method ...
end
```

#### 3. Use for Display

```erb
<% original_names = search_record[:original_transcript_names] || search_record[:transcript_names] %>
<% original_names.uniq.each_with_index do |name, i| %>
  <% if name['type'] == 'primary' %>
    <%= "#{name['first_name']} #{name['last_name']}" %>  <!-- Preserves ? -->
  <% end %>
<% end %>
```

**Pros:**
- Simple, no model changes needed
- Always have original user input
- Useful for audit trail

**Cons:**
- Duplicates data
- Less elegant than Plan A or B

---

## Recommended Solution: Plan A + Plan B Hybrid

### Combined Approach: Preserve `?` AND Track Metadata

1. **Modify UcfTransformer** to NOT strip `?` (Plan A)
2. **Add uncertainty metadata** to SearchName (Plan B, optional)
3. **Update views** to use preserved `?` values

### Why This Works

- ✓ Backward compatible (old records still work)
- ✓ Search can match "Mary" AND "Mary?" (if regex updated)
- ✓ Display shows original intent with `?`
- ✓ Minimal code changes
- ✓ Solves all 4 scenarios

### Implementation Steps (in order)

1. **Update [lib/ucf_transformer.rb](../lib/ucf_transformer.rb)**
   - Preserve `?` in original SearchName
   - Apply `?` to UCF expansions

2. **Update [app/models/search_record.rb](../app/models/search_record.rb)**
   - Add optional `search_with_uncertainty_handling` method
   - Document search behavior change

3. **Add tests** for all 4 scenarios

4. **Run data migration**
   - Option A: Regenerate all SearchRecords from Freereg1CsvEntry
   - Option B: Accept data loss for pre-migration records (< ideal)

5. **Update views** if metadata tracking added

---

## Test Coverage

### Current Test Status

**Files with relevant tests:**
- [spec/integration/search_name_population_from_freereg1csvfile_spec.rb](../spec/integration/search_name_population_from_freereg1csvfile_spec.rb)
- [spec/models/search_record_spec.rb](../spec/models/search_record_spec.rb)
- [spec/lib/ucf_transformer_spec.rb](../spec/lib/ucf_transformer_spec.rb) (if exists)

### Test Scenarios to Add

#### Test 1: Scenario 1 - No UCF, modify no UCF

```ruby
RSpec.describe 'Scenario 1: No UCF, modify with no UCF' do
  let(:entry) { create(:freereg1_csv_entry, person_forename: 'Mary') }
  
  it 'synchronizes question mark across all layers' do
    # Edit: add trailing ?
    entry.update(person_forename: 'Mary?')
    
    # Verify SearchRecord recreated
    search_record = entry.search_record
    
    # Check transcript_names (should have ?)
    expect(search_record.transcript_names[0][:first_name]).to eq('Mary?')
    
    # Check search_names (currently stripped, should be preserved with fix)
    expect(search_record.search_names[0].first_name).to eq('mary?')  # AFTER FIX
    
    # Check search works
    results = SearchRecord.where('search_names.first_name': 'mary?')
    expect(results.size).to be > 0
    
    # Check display
    displayed = search_record.transcript_names[0][:first_name]
    expect(displayed).to eq('Mary?')
  end
end
```

#### Test 2: Scenario 2 - No UCF, modify with UCF

```ruby
RSpec.describe 'Scenario 2: No UCF, modify with UCF' do
  let(:entry) { create(:freereg1_csv_entry, person_forename: 'Mary') }
  
  it 'expands UCF brackets properly' do
    entry.update(person_forename: 'M{1,2}ary')
    search_record = entry.search_record
    
    # Should have original + expansions
    names_by_origin = search_record.search_names.group_by(&:origin)
    expect(names_by_origin['transcript'].size).to eq(1)
    expect(names_by_origin['ucf'].size).to eq(2)
    
    # UCF variants: "mary", "maary"
    ucf_names = names_by_origin['ucf'].map(&:first_name).sort
    expect(ucf_names).to match_array(['mary', 'maary'])
    
    # All searchable
    expect(SearchRecord.where('search_names.first_name': 'mary').exists?).to be true
    expect(SearchRecord.where('search_names.first_name': 'maary').exists?).to be true
  end
end
```

#### Test 3: Scenario 3 - With UCF, modify without UCF

```ruby
RSpec.describe 'Scenario 3: With UCF, modify without UCF' do
  let(:entry) { create(:freereg1_csv_entry, person_forename: 'M_ry') }
  
  before do
    entry.update(person_forename: 'M_ry')
    @original_search_record = entry.search_record
    @original_names = @original_search_record.search_names.map(&:first_name).sort
  end
  
  it 'loses UCF variants when switching to plain name' do
    # CURRENT (BROKEN) BEHAVIOR:
    entry.update(person_forename: 'Mary?')
    search_record = entry.search_record  # NEW record (old destroyed)
    
    new_names = search_record.search_names.map(&:first_name).sort
    
    # UCF variants are lost (mary, mbry, etc. gone)
    expect(new_names).to match_array(['mary'])  # Only original, no ? preserved
    
    # AFTER FIX: Should have original with ?
    # expect(new_names).to match_array(['mary'])  # without ?, would be: 'mary'
    
    # Original record no longer exists
    expect { @original_search_record.reload }.to raise_error(Mongoid::Errors::DocumentNotFound)
  end
end
```

#### Test 4: Scenario 4 - With UCF, modify with different UCF

```ruby
RSpec.describe 'Scenario 4: With UCF, modify with different UCF' do
  let(:entry) { create(:freereg1_csv_entry, person_forename: 'M[ar]y') }
  
  it 'replaces UCF variants when changing pattern' do
    entry.update(person_forename: 'Ma*y')
    search_record = entry.search_record
    
    # Old variants (may, mary) should be gone
    names = search_record.search_names.map(&:first_name).sort
    expect(names).not_to include('may')
    expect(names).not_to include('mary')
    
    # New variants present
    # Exact expansion depends on regex interpretation of *
    expect(names.size).to be > 1  # At least the original + some expansion
  end
end
```

#### Test 5: UcfTransformer preserves trailing `?`

```ruby
RSpec.describe UcfTransformer, '.transform' do
  describe 'trailing question mark handling' do
    it 'preserves question mark in original name' do
      original_name = SearchName.new({
        first_name: 'Mary?',
        last_name: 'Smith?'
      })
      
      result = UcfTransformer.transform([original_name])
      
      # AFTER FIX: First element is original with ?
      expect(result[0].first_name).to eq('Mary?')
      expect(result[0].last_name).to eq('Smith?')
    end
    
    it 'appends question mark to UCF expansions' do
      original_name = SearchName.new({
        first_name: 'M[ar]y?',
        last_name: 'Smith'
      })
      
      result = UcfTransformer.transform([original_name])
      
      # Original + 2 UCF variants
      expect(result.size).to eq(3)
      
      # Original unchanged
      expect(result[0].first_name).to eq('M[ar]y?')
      
      # UCF variants have ? appended
      ucf_variants = result[1..2]
      expect(ucf_variants[0].first_name).to eq('May?')
      expect(ucf_variants[1].first_name).to eq('Mary?')
      expect(ucf_variants.all? { |n| n.origin == 'ucf' }).to be true
    end
  end
end
```

#### Test 6: Search handling with uncertainty

```ruby
RSpec.describe SearchRecord, 'search with uncertainty handling' do
  let!(:mary_certain) { create_baptism('Mary', 'Smith') }
  let!(:mary_uncertain) { create_baptism('Mary?', 'Smith?') }  # After fix
  
  it 'finds records when searching without question mark' do
    # User searches for "Mary" without ?
    # Should find BOTH certain and uncertain variants
    results = SearchRecord.search_with_uncertainty_handling({
      first_name: 'mary'
    })
    
    expect(results.count).to eq(2)
    expect(results).to include(mary_certain, mary_uncertain)
  end
  
  it 'finds only certain records when searching with question mark' do
    # User searches for "Mary?" explicitly
    # Should find ONLY uncertain variant
    results = SearchRecord.search_with_uncertainty_handling({
      first_name: 'mary?'
    })
    
    expect(results.count).to eq(1)
    expect(results).to include(mary_uncertain)
  end
end

def create_baptism(forename, surname)
  entry = create(:freereg1_csv_entry, person_forename: forename, person_surname: surname)
  entry.search_record
end
```

---

## State Transition Diagrams

### Scenario 1: No UCF → No UCF (with ?)

```
┌─────────────────────────────────────────────────────┐
│ Initial State (before edit)                          │
├─────────────────────────────────────────────────────┤
│ Freereg1CsvEntry.person_forename: "Mary"            │
│ SearchRecord.transcript_names[0].first_name: "Mary" │
│ SearchRecord.search_names[0].first_name: "mary"     │
│ SearchRecord.search_names[0].origin: "transcript"   │
└─────────────────────────────────────────────────────┘
                    ↓ [User edits: "Mary?"]
┌─────────────────────────────────────────────────────┐
│ User Update Action                                   │
├─────────────────────────────────────────────────────┤
│ 1. Freereg1CsvEntry.update({'person_forename': 'Mary?'}) │
│ 2. before_save: captitalize_surnames (skips forename)     │
│ 3. entry.save ✓                                    │
│ 4. after_update: update_place_ucf_list              │
└─────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────┐
│ SearchRecord.update_create_search_record             │
├─────────────────────────────────────────────────────┤
│ 1. Freereg1Translator.translate(entry)              │
│    → transcript_names[0] = {first_name: "Mary?", ...} │
│ 2. new SearchRecord.transform():                    │
│    a) populate_search_from_transcript               │
│       → search_names[0] = {fn: "Mary?", ...}        │
│    b) downcase_all                                  │
│       → search_names[0].first_name = "mary?"        │
│    c) transform_ucf() [CURRENT: strips ?]           │
│       ✗ CURRENT: "mary?" → "mary"                  │
│       ✓ AFTER FIX: "mary?" → "mary?" (preserved)   │
│    d) create_soundex                                │
│       → Soundex("mary" or "mary?")                  │
│ 3. old_search_record.destroy                        │
│ 4. new_search_record.save                           │
└─────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────┐
│ Final State (after edit)                             │
├─────────────────────────────────────────────────────┤
│ ✗ CURRENT BEHAVIOR:                                 │
│   Freereg1CsvEntry.person_forename: "Mary?"        │
│   SearchRecord.transcript_names[0].first_name: "Mary?" │
│   SearchRecord.search_names[0].first_name: "mary"  │
│   ❌ MISMATCH: ? lost in search_names               │
│                                                      │
│ ✓ AFTER FIX (Plan A):                              │
│   Freereg1CsvEntry.person_forename: "Mary?"        │
│   SearchRecord.transcript_names[0].first_name: "Mary?" │
│   SearchRecord.search_names[0].first_name: "mary?" │
│   ✅ SYNCHRONIZED                                  │
│                                                      │
│ ✓ AFTER FIX (Plan B - metadata):                   │
│   SearchName.first_name: "mary"                    │
│   SearchName.first_name_uncertain: true            │
│   display_name returns: "mary?"                     │
│   ✅ SYNCHRONIZED                                  │
└─────────────────────────────────────────────────────┘
```

### Scenario 2: No UCF → With UCF

```
┌──────────────────────────────────────────────────────┐
│ Initial State                                         │
├──────────────────────────────────────────────────────┤
│ Freereg1CsvEntry.person_forename: "Mary"            │
│ SearchRecord.search_names:                          │
│   [{first_name: "mary", origin: "transcript"}]     │
└──────────────────────────────────────────────────────┘
                     ↓ [User edits: "M{1,2}ary"]
┌──────────────────────────────────────────────────────┐
│ After Translator & transform_ucf()                   │
├──────────────────────────────────────────────────────┤
│ SearchRecord.search_names:                          │
│   [{first_name: "m{1,2}ary", origin: "transcript"}] │
│   [{first_name: "mary", origin: "ucf"}]            │
│   [{first_name: "maary", origin: "ucf"}]           │
│ ✅ SYNCHRONIZED: All versions present                 │
└──────────────────────────────────────────────────────┘
```

---

## Code Execution Path Summary

```
User Input "Mary?"
    ↓
/app/controllers/freereg1_csv_entries_controller.rb
  update(...)
    ↓
model.update_attributes({person_forename: "Mary?"})
    ↓
[before_save] Freereg1CsvEntry#captitalize_surnames
    (skips forenames)
    ↓
entry.save ✓
    ↓
[after_update] Freereg1CsvEntry#update_place_ucf_list
    ↓
/app/models/search_record.rb
  SearchRecord.update_create_search_record(entry, search_version, place)
    ↓
/lib/freereg1_translator.rb
  Freereg1Translator.translate(entry.freereg1_csv_file, entry)
    ↓
  Freereg1Translator.translate_names_baptism(entry)
    Extracts: first_name: entry.person_forename ("Mary?")
    Returns: [{role: 'ba', type: 'primary', first_name: "Mary?", ...}]
    ↓
new_search_record = SearchRecord.new({transcript_names: [...]})
  transcript_names[0] = {first_name: "Mary?", ...}
    ↓
new_search_record.transform()
    ↓
  new_search_record.populate_search_from_transcript()
    ↓
    new_search_record.populate_search_names()
      search_names << SearchName.new({first_name: "Mary?", ...})
    ↓
  new_search_record.downcase_all()
    search_names[0].first_name = "mary?"
    ↓
  new_search_record.emend_all()
    (no changes unless emendations apply)
    ↓
  new_search_record.transform_ucf()  ← CRITICAL STEP
    ↓
    /lib/ucf_transformer.rb
    UcfTransformer.transform(search_names)
      name.first_name.sub!(/(\w*?)\?/, '\1')
      "mary?" → "mary"  ← QUESTION MARK STRIPPED
      ↓
    RETURNS: [{first_name: "mary", ...}]  ← ? LOST
    ↓
  new_search_record.create_soundex()
    Soundex.soundex("mary") → "M600"
    ↓
  new_search_record.transform_date()
    ↓
  new_search_record.populate_location()
    ↓
new_search_record.save ✓
    ↓
old_search_record.destroy
    ↓
Final SearchRecord:
  {
    transcript_names: [{first_name: "Mary?", ...}],  ← ? KEPT
    search_names: [{first_name: "mary", ...}],       ← ? LOST
    search_soundex: [{first_name: "M600", ...}]
  }
```

---

## Conclusion

### Current State

The trailing `?` character is:
- ✓ **Preserved** in `Freereg1CsvEntry` fields (user input)
- ✓ **Preserved** in `SearchRecord.transcript_names` (display source)
- ✗ **Stripped** in `SearchRecord.search_names` (search source)
- ✗ **Never recoverable** once transformed

### Root Cause

`UcfTransformer.transform()` uses regex substitution to strip the trailing `?` before UCF expansion, treating it as a non-UCF character to be removed.

### Impact

**Scenarios 1 & 3:** Name synchronization FAILS - users see `?` displayed but cannot search for names with `?`

**Scenarios 2 & 4:** Name synchronization SUCCEEDS - UCF variants are properly created

### Solution

**Recommended:** Plan A + optional Plan B
1. Modify `UcfTransformer` to preserve trailing `?`
2. Update search and display logic accordingly
3. Add comprehensive test coverage

**Estimated Effort:** 4-6 hours implementation + testing

---

## References

- **Rails Version:** 5.1.7 (no Rails 6+ APIs)
- **Ruby Version:** 2.7.8
- **MongoDB Version:** 4.4.x
- **Mongoid Version:** 7.1.5
- **No Sidekiq, no replicas, no log aggregator**

---

**End of Document**

Generated: February 21, 2026
Next Review: After implementation of Plan A/B
