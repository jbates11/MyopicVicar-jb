# Why It Works: Architecture & Deep Dive

This document explains the architecture behind the reindex process. **Read this AFTER running Phase 1 (Staging Validation)** to understand what just happened.

**Audience**: Junior developers curious about how the codebase works.  
**Prerequisites**: You've read [index.md](index.md) and [how-to-run-reindex.md](how-to-run-reindex.md).

---

## The Big Picture: How MyopicVicar Handles Marriage Records

```
CSV File (e.g., "St_Mary_1700.csv")
    ↓ (Parse)
Freereg1CsvEntry (MongoDB document, raw fields)
    ↓ (Translator converts to SearchRecord fields)
Freereg1Translator.translate(entry, file)
    ↓ (Returns attributes hash with transcript_names array)
SearchRecord (MongoDB document, denormalized)
    ├─ transcript_names (array from translator)
    ├─ search_names (derived, searchable)
    ├─ search_soundex (derived, phonetic matching)
    └─ search_dates (derived, normalized dates)
    ↓ (User searches)
Search Results (displayed to user)
```

Let's walk through each step.

---

## Step 1: CSV to Freereg1CsvEntry

When a CSV file is imported, each row becomes a document:

**File: `lib/new_freereg_csv_update_processor.rb` (line ~402)**

```ruby
class NewFreeregCsvUpdateProcessor
  def process_entry(row)
    # row is a CSV line, e.g., "John Smith, Jane Doe, 1700-05-15, ..."
    
    entry = Freereg1CsvEntry.create(
      #  ^-- MongoDB document
      freereg1_csv_file: self.file,
      county_code: 'YKS',
      record_type: 'ma',  # marriage
      groom_forename: 'John',
      groom_surname: 'Smith',
      bride_forename: 'Jane',
      bride_surname: 'Doe',
      groom_age: '25',
      bride_age: '22',
      marriage_date: '1700-05-15',
      # ... other fields ...
    )
    
    entry
  end
end
```

**Model: `app/models/freereg1_csv_entry.rb` (line ~1)**

```ruby
class Freereg1CsvEntry
  include Mongoid::Document
  
  field :groom_forename, type: String
  field :groom_surname, type: String
  field :bride_forename, type: String
  field :bride_surname, type: String
  field :groom_age, type: String
  field :marriage_date, type: String
  # ... 30+ more fields ...
  
  belongs_to :freereg1_csv_file
  has_one :search_record  # ← Important relationship
end
```

So now we have: **Raw data in MongoDB** ✅

---

## Step 2: Translator Converts to SearchRecord Fields

The **translator** is a stateless converter. It takes raw CSV data and produces a hash of attributes for SearchRecord.

**File: `lib/freereg1_translator.rb` (line 38)**

```ruby
module Freereg1Translator
  def self.translate(file, entry)
    # Input: file (Freereg1CsvFile), entry (Freereg1CsvEntry)
    # Output: Hash with SearchRecord attributes
    
    {
      # From entry_attributes
      freereg1_csv_entry: entry,
      freereg1_csv_file: file,
      county_code: file.county_code,
      place_id: file.place_id,
      record_type: entry.record_type,  # 'ma', 'ba', 'bu'
      transcript_dates: [...],          # Parsed dates
      transcript_names: translate_names(entry),  # ← Key part!
      
      # From file_attributes
      search_record_version: file.search_record_version,
      # ... other fields ...
    }
  end
  
  private
  
  def self.translate_names(entry)
    case entry.record_type
    when 'ma' then translate_names_marriage(entry)
    when 'ba' then translate_names_baptism(entry)
    when 'bu' then translate_names_burial(entry)
    end
  end
end
```

### The Key Method: translate_names_marriage

**File: `lib/freereg1_translator.rb` (line 100)**

```ruby
def self.translate_names_marriage(entry)
  names = []
  
  # groom first — matches ORIGINAL_MARRIAGE_LAYOUT on detail page
  names << { 
    role: 'g',           # ← Groom is first
    type: 'primary',
    first_name: entry.groom_forename, 
    last_name: entry.groom_surname 
  }
  
  # bride second
  names << { 
    role: 'b',           # ← Bride is second
    type: 'primary',
    first_name: entry.bride_forename, 
    last_name: entry.bride_surname 
  }
  
  # Optional: parents, witnesses
  if entry.groom_father_forename.present?
    names << { 
      role: 'gf',        # ← Groom's father
      type: 'other',
      first_name: entry.groom_father_forename, 
      last_name: entry.groom_father_surname 
    }
  end
  
  if entry.bride_father_forename.present?
    names << { 
      role: 'bf', 
      type: 'other',
      first_name: entry.bride_father_forename, 
      last_name: entry.bride_father_surname 
    }
  end
  
  # ... groom's mother (gm), bride's mother (bm), witnesses (wt) ...
  
  names  # Return array of name hashes
end
```

**Example output** (for John Smith & Jane Doe marriage):

```ruby
[
  { role: 'g', type: 'primary', first_name: 'John', last_name: 'Smith' },
  { role: 'b', type: 'primary', first_name: 'Jane', last_name: 'Doe' }
]
```

The translator **never** touches the database directly. It's a pure function: input (entry) → output (attributes hash). This is why it's safe to re-run! 

So now we have: **Translated attributes hash** ✅

---

## Step 3: SearchRecord Stores Denormalized Data

The SearchRecord model receives the translator's output and stores it:

**Model: `app/models/search_record.rb` (line ~1)**

```ruby
class SearchRecord
  include Mongoid::Document
  
  # Denormalized raw data from translator
  field :transcript_names, type: Array     # ← This is what we're re-indexing!
  field :transcript_dates, type: Array
  field :place_id, type: BSON::ObjectId
  field :record_type, type: String         # 'ma', 'ba', 'bu'
  field :county_code, type: String
  
  # Derived data from transform pipeline
  field :search_names, type: Array         # ← Embedded SearchName objects
  field :search_soundex, type: Array       # ← Phonetic codes
  field :search_dates, type: Array         # ← Normalized dates
  field :digest, type: String              # ← MD5 hash (change detection)
  
  embeds_many :search_names                # Embedded objects
  
  belongs_to :freereg1_csv_entry
  belongs_to :freereg1_csv_file
  belongs_to :place
end
```

**Why denormalize `transcript_names`?**
- ✅ **Fast retrieval**: All data in one document, no joins
- ✅ **Display**: Can show raw names directly without transforming
- ✅ **Search**: Can search by name without rebuilding
- ⚠️ **Trade-off**: If translator logic changes, must re-transform

So now we have: **SearchRecord with transcript_names** ✅

---

## Step 4: Transform Pipeline (The 7-Step Magic)

When a SearchRecord is created or updated, the `transform()` method runs. This is a **7-step pipeline** that converts `transcript_names` into searchable indices.

**File: `app/models/search_record.rb` (line 1020)**

```ruby
def transform
  # Step 1: Create search_names from transcript_names
  populate_search_from_transcript     # Converts raw names → SearchName objects
  
  # Step 2: Downcase for case-insensitive search
  downcase_all
  
  # Step 3: Split compound names
  separate_all        # "John-Paul" → "John", "Paul"
  
  # Step 4: Apply name corrections
  emend_all           # Fixes known misspellings
  
  # Step 5: Unicode normalization
  transform_ucf
  
  # Step 6: Create phonetic variants (Soundex)
  create_soundex      # For fuzzy matching
  
  # Step 7: Normalize dates
  transform_date
end
```

Let's look at the first (most important) step:

### Step 4a: populate_search_from_transcript

**File: `app/models/search_record.rb` (line 906)**

```ruby
def populate_search_from_transcript
  # Input: self.transcript_names (array of name hashes from translator)
  # Output: self.search_names (array of SearchName embedded objects)
  
  self.search_names = []
  
  (self.transcript_names || []).each do |transcript_name|
    search_name = SearchName.new(
      role: transcript_name['role'],                    # 'g', 'b', 'gf', etc.
      forename: transcript_name['first_name'],
      surname: transcript_name['last_name'],
      soundex: '',                                      # Will be filled in Step 6
      type: transcript_name['type']                     # 'primary', 'other'
    )
    
    self.search_names << search_name
  end
end
```

**Example:**

```ruby
# Before transform:
search_record.transcript_names
=> [
     { role: 'g', first_name: 'John', last_name: 'Smith' },
     { role: 'b', first_name: 'Jane', last_name: 'Doe' }
   ]

# After step 1 (populate_search_from_transcript):
search_record.search_names
=> [
     SearchName { role: 'g', forename: 'John', surname: 'Smith', soundex: '', ... },
     SearchName { role: 'b', forename: 'Jane', surname: 'Doe', soundex: '', ... }
   ]

# After step 6 (create_soundex):
search_record.search_names
=> [
     SearchName { role: 'g', forename: 'John', surname: 'Smith', soundex: ['S530'], ... },
     SearchName { role: 'b', forename: 'Jane', surname: 'Doe', soundex: ['D000'], ... }
   ]
```

So now we have: **Searchable indices derived from translated data** ✅

---

## Step 5: Creating a SearchRecord (Integration)

When a CSV entry is ingested, these steps happen automatically:

**File: `app/models/search_record.rb` (line 483)**

```ruby
def self.update_create_search_record(entry, search_version, place)
  # Step 1: Get translated attributes from Freereg1Translator
  attributes = Freereg1Translator.translate(entry.freereg1_csv_file, entry)
  
  # Step 2: Check if this entry has changed (using MD5 digest)
  digest = Digest::MD5.hexdigest(entry.to_json)
  existing_record = entry.search_record
  
  if existing_record&.digest == digest
    return { status: 'no update', record: existing_record }
  end
  
  # Step 3: Create or update SearchRecord
  record = existing_record || SearchRecord.new
  record.attributes = attributes
  record.digest = digest
  record.place = place
  
  # Step 4: Run the 7-step transform pipeline
  record.transform
  
  # Step 5: Save to MongoDB
  record.save!
  
  { status: 'created' or 'updated', record: record }
end
```

**Flow diagram:**
```
Freereg1CsvEntry (raw data)
    ↓ Freereg1Translator.translate()
Translator returns: { transcript_names: [...], ... }
    ↓
SearchRecord.new(attributes)
record.transcript_names = [...]
    ↓ record.transform()
    ├─ Step 1: populate_search_from_transcript
    ├─ Step 2–7: Phonetic, normalization, etc.
    ↓
record.search_names = [SearchName, SearchName, ...]
record.search_soundex = [[...], [...], ...]
    ↓
record.save!  (MongoDB)
```

---

## Step 6: Why Reindex Is Needed

### The Problem: Translator Changes, Documents Don't

**Scenario:**

You have a production database with 234,567 marriage SearchRecords (created over the past 5 years with the **old translator** where bride was first).

```ruby
# Old SearchRecords in MongoDB (before translator change)
SearchRecord {
  _id: ObjectId('5f3c0a...'),
  record_type: 'ma',
  transcript_names: [
    { role: 'b', first_name: 'Jane', last_name: 'Doe' },  # ← Bride FIRST (old translator)
    { role: 'g', first_name: 'John', last_name: 'Smith' }  # ← Groom SECOND
  ]
}
```

You deploy the code change (bride/groom swapped in translator). **The old records don't automatically update!** MongoDB doesn't know the translator changed.

```ruby
# Same SearchRecords NOW (after code deploy, without reindex)
# — Nothing changed! They're still bride-first
SearchRecord {
  _id: ObjectId('5f3c0a...'),
  record_type: 'ma',
  transcript_names: [
    { role: 'b', first_name: 'Jane', last_name: 'Doe' },  # ← Still FIRST
    { role: 'g', first_name: 'John', last_name: 'Smith' }  # ← Still SECOND
  ]
}
```

But **new records created AFTER the deploy** use the new translator:

```ruby
# New SearchRecords (created after code deploy with new translator)
SearchRecord {
  _id: ObjectId('5f4e1b...'),
  record_type: 'ma',
  transcript_names: [
    { role: 'g', first_name: 'John', last_name: 'Smith' },  # ← Groom FIRST (new translator!)
    { role: 'b', first_name: 'Jane', last_name: 'Doe' }     # ← Bride SECOND
  ]
}
```

**Result: Inconsistency!** Some records have bride first, others have groom first, depending on creation date.

### The Solution: Re-Run the Translator

Reindexing re-runs the translator on **all records**, forcing them through the transform pipeline again with the **new translator code**.

**Mechanically:**

```ruby
# The Rake task in lib/tasks/reprocess_batches_for_a_county.rake
task :reprocess_batches_for_a_county do |t, args|
  county_code = args.county_code
  
  files = Freereg1CsvFile.where(county_code: county_code, record_type: 'ma')
  
  files.each do |file|
    file.entries.each do |entry|  # ← Iterate CSV ENTRIES (not SearchRecords!)
      # This is key: we read from the CSV entry, re-translate it,
      # and update the SearchRecord
      
      attributes = Freereg1Translator.translate(file, entry)
      # ↑ New translator produces groom-first order!
      
      sr = entry.search_record
      sr.attributes = attributes
      sr.transform
      sr.save
    end
  end
end
```

**Before reindex:**
```
Freereg1CsvEntry (unchanged, raw CSV data)
  groom_forename: 'John'
  groom_surname: 'Smith'
  bride_forename: 'Jane'
  bride_surname: 'Doe'

SearchRecord (is still bride-first, old order)
  transcript_names: [
    { role: 'b', ... },  # Old order
    { role: 'g', ... }
  ]
```

**During reindex:**
```
Freereg1CsvEntry (read again)
  ↓ Freereg1Translator.translate() with NEW code
  ↓ Produces groom-first transcript_names
SearchRecord gets updated
  transcript_names: [
    { role: 'g', ... },  # NEW order
    { role: 'b', ... }
  ]
  ↓ transform() re-runs
SearchRecord saved back to MongoDB
```

**After reindex:**
```
SearchRecord (now groom-first, new order!)
  transcript_names: [
    { role: 'g', ... },  # New order
    { role: 'b', ... }
  ]
```

So reindexing = **Re-read from source, re-translate, re-transform, re-save.**

---

## Step 7: Why We Use Freereg1CsvEntry as Source (Not SearchRecord)

You might ask: "Why not just iterate SearchRecords directly and update them?"

```ruby
# ❌ WRONG approach: directly modifying SearchRecord
SearchRecord.where(record_type: 'ma').each do |sr|
  sr.transcript_names[0], sr.transcript_names[1] = sr.transcript_names[1], sr.transcript_names[0]
  # ^ This is a hack, not re-translating!
  sr.save
end
```

**Why this is wrong:**
- ❌ Hardcodes the swap logic (brittle)
- ❌ Doesn't use the translator (missed any other changes)
- ❌ Bypasses validation

**Correct approach: Use Freereg1CsvEntry:**

```ruby
# ✅ CORRECT: Re-translate from source of truth
Freereg1CsvEntry.where(record_type: 'ma').each do |entry|
  # entry has all the raw CSV fields (groom_forename, bride_forename, etc.)
  
  attributes = Freereg1Translator.translate(entry.freereg1_csv_file, entry)
  # ^ Uses NEW translator code (groom first!)
  
  sr = entry.search_record
  sr.attributes = attributes
  sr.transform
  sr.save
end
```

**Why this is correct:**
- ✅ Uses __actual translator__ (single source of truth)
- ✅ Future-proof (if translator changes again, reindex still works)
- ✅ Validates data (Mongoid validations run)
- ✅ Runs full 7-step transform (phonetics, etc. all rebuilt)

**Freereg1CsvEntry** is the authoritative source. SearchRecord is derived from it.

---

## Step 8: The Rake Task (Putting It All Together)

**File: `lib/tasks/reprocess_batches_for_a_county.rake` (line ~1)**

```ruby
namespace :freereg do
  desc "Reprocess search records for a county"
  task :reprocess_batches_for_a_county, [:county_code] => :environment do |t, args|
    county_code = args.county_code
    no_timeout
    
    puts "Processing county: #{county_code}"
    
    # Find all CSV files for this county with marriages
    files = Freereg1CsvFile.where(
      county_code: county_code,
      record_type: 'ma'
    ).no_timeout
    
    puts "Freereg1CsvFile count: #{files.count}"
    
    files.each_with_index do |file, file_index|
      puts "Processing file #{file_index + 1}/#{files.count}: #{file.original_filename}"
      
      # Iterate all CSV entries in this file
      file.entries.no_timeout.each_with_index do |entry, entry_index|
        puts "  Processing entry #{entry_index + 1}/#{file.entries.count}..." if entry_index % 100 == 0
        
        # Re-translate and transforms the entry
        SearchRecord.update_create_search_record(entry, file.search_record_version, file.place)
      end
      
      file_count = file.entries.count
      puts "File #{file_index + 1}: #{file_count} records processed"
    end
    
    puts "Completed!"
  end
end
```

**What `.no_timeout` does:**
- Disables MongoDB query timeouts (useful for large counties with 100k+ records)
- Otherwise, queries might timeout and task would fail mid-way

---

## Summary: The Reindex Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Freereg1CsvEntry (source of truth, raw CSV data)         │
│   - groom_forename, groom_surname, bride_forename, bride... │
└────────────────┬────────────────────────────────────────────┘
                 │
                 │ Rake task iterates all entries
                 ↓
         ┌──────────────────┐
         │ Freereg1Translator   
         │ .translate(file, entry)│
         │                  │ NEW CODE (groom first!)
         └────────┬─────────┘
                  ↓
  ┌─────────────────────────────────────────────┐
  │ Translator output attributes hash:          │
  │ {                                           │
  │   transcript_names: [                       │
  │     { role: 'g', first_name: '...', ... },  │ ← GROOM FIRST
  │     { role: 'b', first_name: '...', ... }   │ ← BRIDE SECOND
  │   ],                                        │
  │   ...                                       │
  │ }                                           │
  └──────────────┬──────────────────────────────┘
                 │
                 │ SearchRecord.update_create_search_record()
                 ↓
         ┌─────────────────┐
         │ SearchRecord    │
         │ .transform()    │ 7-step pipeline
         │                 │ (downcase, soundex, etc.)
         └────────┬────────┘
                  ↓
  ┌──────────────────────────────────────────┐
  │ SearchRecord saved to MongoDB:           │
  │ {                                        │
  │   _id: ObjectId(...),                    │
  │   transcript_names: [...],               │ ← Updated (groom first)
  │   search_names: [SearchName({...}), ...] │ ← Rebuilt
  │   search_soundex: [[...], ...]           │ ← Rebuilt
  │   ...                                    │
  │ }                                        │
  └──────────────────────────────────────────┘
                 │
                 ↓
         Repeat for next entry
```

---

## Recap: Why This Architecture Matters

| Concept | Why It Matters |
|---------|----------------|
| **Denormalization** | Fast searches (all data in one document), but requires re-indexing when logic changes |
| **Stateless Translator** | Can safely re-run on old data; produces same output for same input |
| **7-Step Transform** | Normalizes, adds phonetics, handles edge cases; all rebuilt when transcript changes |
| **Freereg1CsvEntry as Source** | Single source of truth; reindex always produces consistent results |
| **Rake Task** | Orchestrates the reindex: iterate entries → translate → transform → save |

---

## Next Steps

- **Ready to reindex?** Jump back to [how-to-run-reindex.md](how-to-run-reindex.md)
- **Want visual diagrams?** Jump to [diagrams.mmd](diagrams.mmd)
- **Something broken?** Jump to [troubleshooting.md](troubleshooting.md)
