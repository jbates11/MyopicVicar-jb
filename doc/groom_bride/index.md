# Re-Indexing Search Records: Bride/Groom Order Swap

## Overview

This guide explains **how to re-run the search record transform** after swapping the order of `bride` and `groom` in [`lib/freereg1_translator.rb`](../../lib/freereg1_translator.rb#L100).

**What changed?** The translator now outputs `groom` first, then `bride` in the `transcript_names` array — matching the original layout on the detail page.

**Why does this matter?** Marriage records in MongoDB store a denormalized `transcript_names` field. When the translator changes, old records keep the old order unless you re-transform them. **Failing to re-index means searches will show bride-first for old records, groom-first for new records — inconsistent results.**

**How long does it take?**
- Staging validation: ~15–30 minutes
- Production (one county): 15 minutes to 2 hours, depending on county size
- Full production (all counties): 2–4 hours total, run county-by-county with zero downtime

---

## Quick Decision Tree

**Use this to find your next step:**

```
Are you ready to deploy the bride/groom swap to production?
│
├─ NO: I want to test first on staging
│   └─→ Go to "Staging Validation" in how-to-run-reindex.md
│
└─ YES: I'm ready for production
    │
    ├─ Do I need zero downtime (searches must stay online)?
    │  │
    │  ├─ YES: Run county-by-county (recommended)
    │  │   └─→ Go to "Phase 2: Production (County-by-County)" in how-to-run-reindex.md
    │  │
    │  └─ NO: Can briefly take searches offline?
    │      └─→ Go to "Advanced: Full Database Reindex" in how-to-run-reindex.md
    │
    └─ Help! Something went wrong
        └─→ Go to troubleshooting.md
```

---

## Document Map

| Document | Purpose | Audience |
|----------|---------|----------|
| **[how-to-run-reindex.md](how-to-run-reindex.md)** | Copy-paste commands for staging validation and production reindex (county-by-county or full database) | Operators, junior developers |
| **[why-it-works.md](why-it-works.md)** | Deep explanation: How the translator works, why SearchRecord stores denormalized data, the 7-step transform pipeline | Junior developers, curious operators |
| **[diagrams.mmd](diagrams.mmd)** | Mermaid diagrams: Data flow (CSV → SearchRecord), reindex lifecycle | Visual learners |
| **[troubleshooting.md](troubleshooting.md)** | Common problems (timeouts, partial reindex, verification failures) and solutions | Operators, debugging |

---

## Key Concepts (No Prior Knowledge Assumed)

### What Is a "Transform"?

A **transform** is a multi-step pipeline that converts raw CSV data into a searchable MongoDB document.

**Simple example:**
```
Raw CSV row: groom_forename="John", groom_surname="Smith", bride_forename="Jane", bride_surname="Doe"
    ↓ (Translator)
transcript_names array: [ {role: 'g', first_name: 'John', last_name: 'Smith'}, {role: 'b', first_name: 'Jane', last_name: 'Doe'} ]
    ↓ (Transform pipeline)
search_names array: [SearchName#1 (John Smith, searchable, soundex codes), SearchName#2 (Jane Doe, searchable, soundex codes)]
```

The transform adds **phonetic variants** (soundex), **name separations** (compound names split), **corrections**, and **case normalization** so that searches work reliably.

### What Is Denormalization?

In MongoDB, **denormalization** means storing the same data in multiple places for fast retrieval.

**Example in MyopicVicar:**
```
SearchRecord (MongoDB document) {
  _id: ObjectId(...),
  transcript_names: [ ... raw array from translator ... ],  // ← Denormalized (stored here)
  search_names: [ ... transformed SearchName objects ... ],  // ← Also stored here (derived from transcript_names)
  search_soundex: [ ... phonetic codes ... ]                 // ← Also stored here (derived from transcript_names)
}
```

**Why denormalize?**
- ✅ Searches are **fast** — no joins needed, all data in one document
- ✅ Display is **fast** — `transcript_names` is ready to show to users
- ⚠️ Trade-off: If translator logic changes, you must **re-transform** old documents

---

## The Bride/Groom Scenario

### Before (Old Order)

```ruby
def self.translate_names_marriage(entry)
  names = []
  # bride first ← OLD ORDER
  names << { role: 'b', type: 'primary', first_name: entry.bride_forename, last_name: entry.bride_surname }
  # groom second
  names << { role: 'g', type: 'primary', first_name: entry.groom_forename, last_name: entry.groom_surname }
  # ... other names (parents, witnesses)
  names
end
```

Marriage record for "John Smith married Jane Doe" would have `transcript_names` as:
```json
[
  { "role": "b", "first_name": "Jane", "last_name": "Doe" },    // Bride FIRST
  { "role": "g", "first_name": "John", "last_name": "Smith" }   // Groom SECOND
]
```

### After (New Order)

```ruby
def self.translate_names_marriage(entry)
  names = []
  # groom first — matches ORIGINAL_MARRIAGE_LAYOUT on detail page ← NEW ORDER
  names << { role: 'g', type: 'primary', first_name: entry.groom_forename, last_name: entry.groom_surname }
  # bride second
  names << { role: 'b', type: 'primary', first_name: entry.bride_forename, last_name: entry.bride_surname }
  # ... other names
  names
end
```

Same marriage now has `transcript_names` as:
```json
[
  { "role": "g", "first_name": "John", "last_name": "Smith" },   // Groom FIRST
  { "role": "b", "first_name": "Jane", "last_name": "Doe" }      // Bride SECOND
]
```

### The Problem: Inconsistency Without Re-Indexing

If you change the translator **without** re-indexing:

| Record ID | Created | transcript_names[0] | Problem |
|-----------|---------|---------------------|---------|
| SR-001 | Before swap | Jane Doe (bride) | ❌ Inconsistent |
| SR-002 | After swap | John Smith (groom) | ✅ Consistent |

**User impact:** Searches and displays show bride first in old records, groom first in new records. **Confusing and unprofessional.**

### The Solution: Re-Run the Transform

Re-indexing re-runs the translator on each CSV entry and updates the SearchRecord:

```
Old SearchRecord (before reindex):
{
  _id: SR-001,
  transcript_names: [ {role: 'b', first_name: 'Jane', ...}, {role: 'g', first_name: 'John', ...} ]
}
  ↓ Reindex (reads from CSV entry, re-translates)
New SearchRecord (after reindex):
{
  _id: SR-001,
  transcript_names: [ {role: 'g', first_name: 'John', ...}, {role: 'b', first_name: 'Jane', ...} ]  ← SWAPPED
}
```

---

## How This Guide Is Organized

1. **Start here** (you are here) — Understand the scope and decision tree
2. **[how-to-run-reindex.md](how-to-run-reindex.md)** — Follow step-by-step commands
   - Phase 1: Staging validation (safe, local testing)
   - Phase 2: Production (county-by-county, zero downtime)
   - Phase 3: Advanced options (troubleshooting, custom filters)
3. **[why-it-works.md](why-it-works.md)** — Understand the architecture
   - How the translator works: [lib/freereg1_translator.rb](../../lib/freereg1_translator.rb)
   - What triggers a reindex: Rake task in [lib/tasks/reprocess_batches_for_a_county.rake](../../lib/tasks/reprocess_batches_for_a_county.rake)
   - The 7-step transform pipeline in [SearchRecord#transform](../../app/models/search_record.rb#L1020)
4. **[diagrams.mmd](diagrams.mmd)** — Visual flowcharts of data flow and reindex process
5. **[troubleshooting.md](troubleshooting.md)** — Common issues and fixes

---

## Summary: Before You Start

| Item | Details |
|------|---------|
| **What changed?** | Bride/groom order swapped in `lib/freereg1_translator.rb#L100` |
| **Why re-index?** | Denormalized `transcript_names` field in SearchRecord won't auto-update |
| **When?** | Before deploying the swap to production (run staging validation first) |
| **Downtime needed?** | No — county-by-county approach keeps searches online |
| **How long?** | 15 min–2 hours per county; 2–4 hours for full database |
| **Risk?** | Low if you follow Phase 2 (county-by-county); validate on staging first |
| **Command to run?** | `rake freereg:reprocess_batches_for_a_county[COUNTY_CODE]` |

---

## Next Steps

- **If testing first**: Jump to [how-to-run-reindex.md → Staging Validation](how-to-run-reindex.md#staging-validation)
- **If ready for production**: Jump to [how-to-run-reindex.md → Phase 2](how-to-run-reindex.md#phase-2-production-county-by-county)
- **If curious about architecture**: Jump to [why-it-works.md](why-it-works.md)
- **If something breaks**: Jump to [troubleshooting.md](troubleshooting.md)
