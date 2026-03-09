# How to Run the Search Record Transform (Step-by-Step)

## Phase 1: Staging Validation (Recommended First Step)

**Goal**: Verify the reindex process works correctly before touching production.

**Time**: ~15–30 minutes  
**Risk**: None — staging is isolated from production  
**What you'll do**: Run one complete county reindex on staging, then verify results

### Step 1: Connect to Staging

```bash
# SSH into your staging server
ssh staging-user@staging-server.example.com

# Or if using Docker Compose locally:
docker-compose up -d  # Start db, mongodb, web
docker-compose exec web bash
```

### Step 2: Verify the Translator Change

Before reindexing, confirm the code change is in place:

```bash
# Check that groom is now FIRST in translate_names_marriage
grep -A 5 "def self.translate_names_marriage" lib/freereg1_translator.rb
```

**Expected output** (groom first):
```ruby
def self.translate_names_marriage(entry)
  names = []
  # groom first — matches ORIGINAL_MARRIAGE_LAYOUT on detail page
  names << { role: 'g', type: 'primary',
             first_name: entry.groom_forename, last_name: entry.groom_surname }
  # bride second
  names << { role: 'b', type: 'primary',
             first_name: entry.bride_forename, last_name: entry.bride_surname }
```

If you see bride first, the code change hasn't been deployed yet. **Stop here and deploy first.**

### Step 3: Choose a Small Staging County

Pick a county with reindexable data. Examples:
- FreeREG counties (any UK county code): YKS, SOM, DEV, etc.
- Common codes: `YKS` (Yorkshire), `SOM` (Somerset), `DEV` (Devon)

For this guide, we'll use **YKS** as an example. Adjust as needed.

### Step 4: Run the Reindex Task

```bash
# Inside the Rails environment (docker-compose exec web bash or SSH shell)
cd /app  # or your Rails root directory

# Run the reindex task for one county
bundle exec rake freereg:reprocess_batches_for_a_county[YKS]
```

**What this does:**
1. Finds all `Freereg1CsvFile` records for county YKS
2. For each file, iterates all `Freereg1CsvEntry` records
3. Calls `Freereg1Translator.translate()` on each entry (using the NEW translator)
4. Updates the corresponding `SearchRecord` with new `transcript_names`
5. Runs the 7-step transform pipeline to rebuild `search_names`
6. Saves the updated document back to MongoDB

**Expected output:**
```
Processing county: YKS
Freereg1CsvFile count: 12
Processing file 1/12: St_Mary_Nottingham_1558.csv
  Processing entry 1/345...
  Processing entry 2/345...
  ...
File 1: 345 records processed
Processing file 2/12: All_Saints_Nottingham_1600.csv
  ...
Total records processed: 4128
Completed in 42 seconds
```

### Step 5: Check for Errors

**If the task completed successfully**, you'll see no errors. If there are errors, jump to [troubleshooting.md](troubleshooting.md#task-fails-with-timeout-error).

### Step 6: Verify Results in MongoDB

Now let's confirm the bride/groom order actually flipped:

```bash
# Connect to MongoDB shell
mongosh  # or `mongo` if using older MongoDB shell

# Switch to MyopicVicar database (adjust name as needed)
use myopicvicar_staging

# Find a marriage record from YKS
db.search_records.findOne({ 
  record_type: 'ma',
  county_code: 'YKS'
})
```

**Expected output** (notice `transcript_names[0].role` is `'g'`):
```json
{
  "_id": ObjectId("..."),
  "record_type": "ma",
  "county_code": "YKS",
  "transcript_names": [
    {
      "role": "g",                       // ← GROOM FIRST (new order)
      "type": "primary",
      "first_name": "John",
      "last_name": "Smith"
    },
    {
      "role": "b",                       // ← BRIDE SECOND (new order)
      "type": "primary",
      "first_name": "Jane",
      "last_name": "Doe"
    }
  ],
  "search_names": [ ... ],
  "search_soundex": [ ... ]
}
```

**If you see bride first (`"role": "b"`), the reindex didn't apply.** Check logs and jump to [troubleshooting.md](troubleshooting.md#transcript_names-unchanged-after-reindex).

### Step 7: Manual Verification (Important!)

Pick 5–10 marriage records and verify by eye:

```bash
# Get 5 random marriage records
db.search_records.find({ 
  record_type: 'ma',
  county_code: 'YKS'
}).limit(5).pretty()
```

For each record:
- ✅ `transcript_names[0].role` should be `'g'` (groom)
- ✅ `transcript_names[1].role` should be `'b'` (bride)
- ✅ Other fields like `search_names` should be populated

**Exit MongoDB shell:**
```bash
exit
```

### Step 8: Test Search Results (Optional but Recommended)

If your staging environment has a Rails console or web interface, search for a bride's name:

```bash
# Open Rails console
bundle exec rails console

# Test a search (adjust SearchRecord query as needed)
bride_name = "Jane Doe"
results = SearchRecord.search(bride_name)
results.first.transcript_names

# Expected: groom John Smith appears SECOND in the array
```

If available via web UI, try searching for "Jane Doe" and confirm John Smith appears in results.

### Staging Validation: Complete ✅

You've successfully validated the reindex process on staging! All checks passed:
- ✅ Translator has new code
- ✅ Reindex task runs without errors
- ✅ MongoDB documents updated with groom-first order
- ✅ Manual spot checks confirm the change

**Next step**: Jump to [Phase 2: Production (County-by-County)](#phase-2-production-county-by-county) or ask your team lead for approval.

---

---

## Phase 2: Production (County-by-County)

**Goal**: Reindex production marriage records with ZERO downtime.

**Approach**: Reindex one county at a time so searches stay available during the operation.

**Time per county**: 15 minutes to 2 hours (depends on county size)  
**Risk**: Low — county-by-county limits blast radius  
**Downtime**: Zero (searches stay online for other counties)

### Why County-by-County?

| Approach | Risk | Speed | Reschedule-ability | User Impact |
|----------|------|-------|-------------------|-------------|
| All at once | High — if fails, all counties affected | Fast (2–4 hrs) | Hard | All searches down |
| County-by-county | Low — if fails, one county affected | Slower (2–4 hrs spread over days) | Easy — resume tomorrow | Single county temporarily slow |

**County-by-county is safer for production.** You can pause between counties, monitor errors, and recover quickly.

### Preparation Checklist

Before starting, verify:

```bash
# 1. You have production access
ssh prod-user@production-server.example.com
cd /app

# 2. Current code has the bride/groom swap
git log --oneline -5  # See recent commits
grep -A 2 "groom first" lib/freereg1_translator.rb  # Confirm change is deployed

# 3. MongoDB and Rails are healthy
bundle exec rails runner "p Mongoid.default_client.database.name"  # Should return database name
# Should output: "myopicvicar_production" (or your DB name)

# 4. You have a list of counties to reindex
# For FreeREG: All UK counties (52 Chapman codes)
# For FreeCEN: All census years/counties
# Example counties: YKS, SOM, DEV, CON, GLS, NTT, ...
```

### Step 1: Choose Your Reindex Batch

**Option A: Full Production (All Counties)**
```bash
# List all counties with marriage records
bundle exec rails runner "
  counties = Freereg1CsvFile
    .where(record_type: 'ma')
    .distinct(:county_code)
    .sort
  puts counties.join(', ')
"
# Output: CAM, CHE, CON, CUM, DBY, DEV, DOR, DUR, ESS, ...
```

**Option B: Specific Template (FreeREG, FreeCEN, FreeBMD)**
```bash
# See only counties for a specific template
bundle exec rails runner "
  # Adjust based on your template
  counties = Freereg1CsvFile
    .where(record_type: 'ma')  # Or 'ba', 'bu' for other types
    .distinct(:county_code)
    .sort
  puts 'Total counties: ' + counties.count.to_s
  puts counties.join(', ')
"
```

Pick your counties and create a list:
```bash
cat > /tmp/counties_to_reindex.txt << 'EOF'
YKS
SOM
DEV
CON
GLS
NTT
EOF
```

### Step 2: Reindex First County (With Monitoring)

Start with the first county in your list. We'll check timing and logs carefully.

**Run the reindex:**
```bash
# Open a terminal multiplexer (tmux or screen) so you can monitor logs
tmux new-session -d -s reindex_session "bundle exec tail -f log/production.log | grep -E '(freereg|reprocess)'"

# In another terminal, run the task
time bundle exec rake freereg:reprocess_batches_for_a_county[YKS]
```

The `time` command shows you how long it took (useful for planning subsequent counties).

**Expected output:**
```
Processing county: YKS
  12 files, 4128 total records
  Time elapsed: 42 seconds
  
real    0m42.123s
user    0m30.456s
sys     0m5.678s
```

**While the task runs, monitor:**
1. **Rails log** (in tmux):
   - Look for `ERROR` or `TIMEOUT` messages
   - Expected: Periodic `Processing file N/M...` messages every 10–30 seconds

2. **Database load** (in another terminal):
   ```bash
   # Monitor MongoDB connections and queries
   mongosh
   > db.currentOp()  # See active operations
   > db.serverStatus().connections  # See connection count
   ```

3. **Rails process**:
   ```bash
   # Monitor CPU/memory usage
   top -p $(pgrep -f "puma\|rails")
   ```

### Step 3: Verify the First County

```bash
# Check a handful of records to confirm groom is now first
mongosh
> use myopicvicar_production
> db.search_records.findOne({ record_type: 'ma', county_code: 'YKS' })
# Should see transcript_names[0].role = 'g'

> db.search_records.countDocuments({ record_type: 'ma', county_code: 'YKS' })
# Note the count (e.g., 4128)
```

### Step 4: Repeat for Remaining Counties

Once the first county is verified, reindex the rest in sequence:

```bash
# Create a simple loop script
cat > /tmp/reindex_all_counties.sh << 'EOF'
#!/bin/bash
set -e  # Exit if any command fails

COUNTIES="YKS SOM DEV CON GLS NTT ESS BRK HAM HRT SHR STF WAR WOR ZET"

for county in $COUNTIES; do
  echo ""
  echo "======================================"
  echo "Reindexing county: $county"
  echo "======================================"
  
  start_time=$(date +%s)
  bundle exec rake freereg:reprocess_batches_for_a_county[$county]
  end_time=$(date +%s)
  
  duration=$((end_time - start_time))
  echo "✓ $county completed in $duration seconds"
  
  # Optional: Small delay between counties to avoid database storm
  sleep 10
done

echo ""
echo "======================================"
echo "All counties reindexed!"
echo "======================================"
EOF

chmod +x /tmp/reindex_all_counties.sh
/tmp/reindex_all_counties.sh
```

Or reindex manually, one at a time, to intervene if needed:

```bash
# County 1
time bundle exec rake freereg:reprocess_batches_for_a_county[YKS]
# ... verify ...
# County 2
time bundle exec rake freereg:reprocess_batches_for_a_county[SOM]
# ... verify ...
# And so on
```

### Step 5: Monitor Searches During Reindex (Optional)

While reindex is running, searches should still work fine for other counties. You can spot-check:

```bash
# In a separate terminal, periodically search
while true; do
  count=$(mongosh myopicvicar_production --quiet --eval \
    "db.search_records.countDocuments({ record_type: 'ma' })")
  echo "$(date): Marriage records in DB: $count"
  sleep 30
done
```

### Step 6: Final Verification (After All Counties)

Once all counties are reindexed, run a sanity check:

```bash
# Count marriage records that have groom FIRST (new order)
mongosh
> use myopicvicar_production
> db.search_records.find({
    record_type: 'ma',
    'transcript_names.0.role': 'g'  // First name's role is 'g'
  }).count()
```

Compare this to your earlier count:
- **Before reindex**: Various counts per county, some groom-first (new records), some bride-first (old)
- **After reindex**: All should be groom-first (role: 'g')

### Step 7: Communicate Results

Notify your team:

```
✅ Reindex Complete

Counties processed: 52 (all UK)
Marriage records updated: 234,567
Total time: 3 hours 42 minutes
Downtime: 0 minutes (zero-downtime, county-by-county approach)

Verification: All marriage records now have groom FIRST in transcript_names.
No errors during reindex.

Searches tested and working normally.
```

---

---

## Phase 3: Advanced Options

### Option A: Reindex Only New Records (Custom Filter)

If you only want to reindex marriages created **after** a specific date (to avoid re-processing old records), you can use a custom script:

```bash
# Create a custom task
cat > lib/tasks/reindex_marriages_after_date.rake << 'EOF'
namespace :freereg do
  desc "Reindex marriage records created after a specific date"
  task :reindex_marriages_after_date, [:date_isoformat] => :environment do |t, args|
    cutoff_date = Time.iso8601(args.date_isoformat)
    
    files = Freereg1CsvFile.where(
      record_type: 'ma',
      created_at: { '$gte' => cutoff_date }
    )
    
    puts "Reindexing #{files.count} files with marriages created after #{cutoff_date}"
    
    files.each do |file|
      file.entries.where(record_type: 'ma').each do |entry|
        sr = entry.search_record
        sr.transform
        sr.save
      end
    end
    
    puts "Done!"
  end
end
EOF

# Run it
time bundle exec rake freereg:reindex_marriages_after_date['2024-01-01T00:00:00Z']
```

### Option B: Reindex with Progress Bar

For very large counties, use a progress bar:

```bash
# Install progress bar gem (if not already installed)
gem install progressbar

# Create task
cat > lib/tasks/reindex_with_progress.rake << 'EOF'
namespace :freereg do
  desc "Reindex with progress bar"
  task :reindex_with_progress, [:county_code] => :environment do |t, args|
    county = args.county_code
    
    files = Freereg1CsvFile.where(
      county_code: county,
      record_type: 'ma'
    ).to_a
    
    total_records = files.sum { |f| f.entries.count }
    progress_bar = ProgressBar.new(total_records)
    
    files.each do |file|
      file.entries.each do |entry|
        sr = entry.search_record
        sr.transform
        sr.save
        progress_bar.increment!
      end
    end
    
    progress_bar.finish
    puts "\n✓ Completed!"
  end
end
EOF

time bundle exec rake freereg:reindex_with_progress[YKS]
```

### Option C: Parallel Reindex (All Counties Simultaneously)

⚠️ **Only use this if database can handle high load!**

```bash
# Reindex all counties in parallel (4 counties at once)
cat > /tmp/parallel_reindex.sh << 'EOF'
#!/bin/bash
COUNTIES="YKS SOM DEV CON GLS NTT ESS BRK HAM HRT SHR STF WAR WOR ZET"
PARALLEL_JOBS=4

echo "$COUNTIES" | tr ' ' '\n' | \
  xargs -P $PARALLEL_JOBS -I {} \
    bash -c 'echo "Starting {}"; time bundle exec rake freereg:reprocess_batches_for_a_county[{}]; echo "✓ {} complete"'
EOF

chmod +x /tmp/parallel_reindex.sh
/tmp/parallel_reindex.sh
```

**Risks:** High database load, harder to debug if a county fails. **Use only if staging tests show no issues.**

### Option D: Resume Interrupted Reindex

If reindex stops midway (e.g., timeout), resume from where it left off:

```bash
# Find which counties have been fully reindexed
mongosh
> use myopicvicar_production
> counties_complete = ["YKS", "SOM", "DEV"];  // Already done
> 
> remaining = ["CON", "GLS", "NTT", "ESS", "BRK", "HAM", "HRT"];  // Still need

# Continue from there
for county in CON GLS NTT ESS BRK HAM HRT; do
  time bundle exec rake freereg:reprocess_batches_for_a_county[$county]
done
```

---

## Verification Checklist (Summary)

After reindex, use this checklist:

```markdown
- [ ] All targeted counties reindexed without errors in logs
- [ ] Spot-checked 10+ marriage records; groom appears FIRST in transcript_names
- [ ] Searched for bride names; groom appears in results (second position)
- [ ] Searched for groom names; bride appears in results (second position)
- [ ] No "timed out" errors in Rails logs
- [ ] Search performance unchanged (latency ~100–500ms)
- [ ] No increase in MongoDB CPU/memory
- [ ] Team notified of completion
- [ ] Documentation updated (e.g., release notes)
```

---

## Next Steps

- **Reindex is complete?** Celebrate! 🎉 Now jump to [why-it-works.md](why-it-works.md) if you want to understand the architecture deeper.
- **Something went wrong?** Jump to [troubleshooting.md](troubleshooting.md).
- **Want to see diagrams?** Jump to [diagrams.mmd](diagrams.mmd).
