# Troubleshooting Guide

**Use this if something goes wrong during staging validation or production reindex.**

Each section has:
1. **Problem**: What went wrong
2. **Why it happened**: Root cause
3. **How to fix it**: Step-by-step solution
4. **Prevention**: How to avoid next time

---

## Task Hangs or Times Out

### Problem

The Rake task starts but never finishes. It says "Processing entry X/Y" and then stops for hours.

```bash
bundle exec rake freereg:reprocess_batches_for_a_county[YKS]
# Output stops here:
# Processing file 3/12: St_Mary_Church.csv
#   Processing entry 150/500...
# [waits forever, never shows more entries]
```

### Why It Happened

- **Large county**: County has 100k+ records; transform takes hours
- **Database overload**: MongoDB or Rails CPU/memory maxed out
- **Network timeout**: Connection lost between Rails and MongoDB
- **Query timeout**: MongoDB internal query timed out (MongoDB max timeout = 1 hour by default)

### How to Fix It

**Option 1: Wait Longer (If Database is Healthy)**

The Rake task uses `.no_timeout`, which disables timeouts. If the server is just busy, give it time:

```bash
# Monitor in a separate terminal while task runs
watch -n 5 'ps aux | grep -E "(puma|rails|rake)"'  # See CPU usage
top -p $(pgrep -f rake)                            # Monitor rake process specifically
```

If you see CPU/memory usage is high (60%+ CPU, grow in memory), **let it continue**. It's working, just slow.

**Option 2: Check Database Health**

```bash
# In another terminal, connect to MongoDB
mongosh
> use myopicvicar_production
> db.serverStatus()  # See overall health

# Kill stuck queries (if any)
> db.aggregate([{ $currentOp: { 'anySessions': true } }])  # See active ops
> db.killOp(123456)  # Kill specific operation by ID
```

**Option 3: Increase Database Timeout (If Available)**

```bash
# In mongosh, set query timeout to 30 minutes
db.adminCommand({ setParameter: 1, operationProfiling: { slowOpThresholdMs: 30000 } })
```

**Option 4: Restart and Resume (Last Resort)**

If the task truly hangs for >2 hours:

```bash
# Kill the hanging task
pkill -f "rake freereg:reprocess_batches_for_a_county"

# Check which counties are complete
mongosh myopicvicar_production
> completed = db.search_records.distinct('county_code', { 'transcript_names.0.role': 'g' })
> completed.sort()

# Determine which counties still need reindex
# Example: if YKS is complete, continue with SOM, DEV, etc.

# Resume
time bundle exec rake freereg:reprocess_batches_for_a_county[SOM]
```

### Prevention

- **Staging first**: Test on a small county to understand timing
- **Off-peak**: Run during low-traffic hours (2–4 AM) to reduce database load
- **County by county**: Don't try all counties at once; handle timeouts one at a time
- **Monitor**: Keep `top` or `mongosh` open in a separate terminal while task runs

---

---

## transcript_names Unchanged After Reindex

### Problem

After reindex completes, you check a SearchRecord but `transcript_names` still shows **bride first** (old order):

```bash
mongosh myopicvicar_production
> db.search_records.findOne({ county_code: 'YKS', record_type: 'ma' })
> // Output shows:
> // transcript_names: [
> //   { role: 'b', first_name: 'Jane', ... },  # Still bride first!
> //   { role: 'g', first_name: 'John', ... }
> // ]
```

### Why It Happened

1. **Code wasn't deployed**: The swap is still in git but not deployed to production
2. **Wrong file checked**: You're checking a record from a different county that wasn't reindexed yet
3. **Wrong database**: You're checking staging database instead of production
4. **Reindex didn't actually run**: Rake task output said "complete" but skipped items

### How to Fix It

**Step 1: Verify Code is Deployed**

```bash
# SSH into production server and check code
ssh prod-user@production-server
cd /app

# Confirm bride/groom swap is in the code
grep -A 3 "groom first" lib/freereg1_translator.rb

# Expected output:
# # groom first — matches ORIGINAL_MARRIAGE_LAYOUT on detail page
#   names << { role: 'g', type: 'primary',
```

If you see **bride first** in the code, the code change hasn't been deployed. **Deploy it and rerun reindex.**

**Step 2: Verify You're Checking the Right Database**

```bash
# Confirm which database you're connected to
mongosh
> db.getName()  # Should return "myopicvicar_production"

# If returns "myopicvicar_staging", switch:
> use myopicvicar_production
```

**Step 3: Verify the Correct County Was Reindexed**

```bash
# Check which counties have groom-first order (after reindex)
mongosh myopicvicar_production
> completed = db.search_records.distinct('county_code', { 'transcript_names.0.role': 'g' })
> completed.sort()

# Should list all counties you reindexed
# Example output: ["CON", "DEV", "DOR", "DUR", ...]

# If YKS is missing, reindex wasn't run for YKS
```

**Step 4: Check Rake Task Logs**

```bash
# Look at Rails logs during/after reindex
tail -200 log/production.log | grep -E "(reprocess|freereg|error)"

# Watch for:
# - "ERROR" messages (actual errors)
# - "Completed!" (successful completion)
# - "Processing" lines (confirms entries were iterated)
```

**Step 5: Reindex the County Again**

If code is deployed correctly but transcript_names didn't change, re-run the Rake task:

```bash
cd /app
time bundle exec rake freereg:reprocess_batches_for_a_county[YKS]

# After completion, verify again
mongosh myopicvicar_production
> db.search_records.findOne({ county_code: 'YKS', record_type: 'ma', 'transcript_names.0.role': 'g' }).transcript_names
```

### Prevention

- **Deploy before reindex**: Always deploy code changes FIRST, then run reindex
- **Check code**: `grep` for "groom first" before running task
- **Verify database**: Always confirm `mongosh` is connected to production (not staging)
- **Verify county**: Check that the county you reindexed actually got updated using the verification query

---

---

## Rake Task Fails: "No Such File or Directory"

### Problem

Task fails with error:

```
Error: lib/tasks/reprocess_batches_for_a_county.rake: No such file or directory
Command not found: rake freereg:reprocess_batches_for_a_county
```

### Why It Happened

- **Wrong directory**: You're not in the Rails root directory
- **Rake not installed**: Bundler gems haven't been installed
- **Typo in command**: Task name is misspelled

### How to Fix It

**Step 1: Verify Rails Root**

```bash
# You should be in /app (or your Rails root)
pwd  # Should output /app or /path/to/myopicvicar

# If not, change directory
cd /app
```

**Step 2: Verify Rake Task Exists**

```bash
# List all freereg tasks
bundle exec rake -T | grep freereg

# Should output:
# rake freereg:reprocess_batches_for_a_county[county_code]    # Reprocess search records...
```

If nothing is shown, the task file doesn't exist. Check:

```bash
ls -la lib/tasks/reprocess_batches_for_a_county.rake

# Should exist. If not, check git:
git log --oneline -- lib/tasks/reprocess_batches_for_a_county.rake
git status lib/tasks/  # See if file was deleted
```

**Step 3: Verify Bundler**

```bash
# Install gems if needed
bundle install

# Verify rake is available
bundle exec rake --version  # Should output version

# Try task again
bundle exec rake freereg:reprocess_batches_for_a_county[YKS]
```

### Prevention

- **Always use `bundle exec`**: Ensures bundler gems are used
- **Check pwd**: Confirm you're in Rails root (`/app` typically)
- **Double-check task name**: Use `rake -T | grep freereg` to see exact name

---

---

## Database Connection Error

### Problem

Task fails with:

```
MongoDB::Error::NoServersAvailable: No servers available
Connection refused (Errno::ECONNREFUSED)
```

### Why It Happened

- **MongoDB not running**: Server crashed or wasn't started
- **Wrong connection string**: `MONGO_URL` environment variable is wrong
- **Network timeout**: MongoDB server is unreachable from Rails

### How to Fix It

**Step 1: Check MongoDB Status**

```bash
# If using Docker:
docker ps | grep mongodb  # Should show container running
docker logs mongodb_container_name  # See MongoDB logs

# If using local MongoDB:
ps aux | grep mongod  # Should see mongod process running

# If using hosted MongoDB (Atlas, etc.):
# Check your provider's dashboard for connection status
```

**Step 2: Test MongoDB Connection**

```bash
# Try connecting directly
mongosh mongodb://localhost:27017

# If this fails, MongoDB is not accessible
# If it works, Rails connection string is wrong
```

**Step 3: Check Rails Environment Variables**

```bash
# Check MONGO_URL
bundle exec rails runner "puts ENV['MONGO_URL']"

# Should output something like:
# mongodb://localhost:27017/myopicvicar_production

# If blank or wrong, set it:
export MONGO_URL="mongodb://localhost:27017/myopicvicar_production"

# Then retry task
time bundle exec rake freereg:reprocess_batches_for_a_county[YKS]
```

**Step 4: Restart MongoDB (If Needed)**

```bash
# Using Docker:
docker restart mongodb_container_name

# Using systemd (local):
sudo systemctl restart mongod

# Wait 10 seconds for startup
sleep 10

# Retry task
time bundle exec rake freereg:reprocess_batches_for_a_county[YKS]
```

### Prevention

- **Pre-check**: Before running reindex, confirm MongoDB is up
  ```bash
  mongosh --eval "db.adminCommand('ping')"  # Should return { ok: 1 }
  ```
- **Use docker-compose**: Ensures all services start together
  ```bash
  docker-compose up -d  # Starts db, mongodb, web
  ```

---

---

## Partial Reindex (Some Counties Done, Some Not)

### Problem

You reindexed YKS and SOM, then the task crashed. Now:
- YKS: ✓ All groom-first (reindexed)
- SOM: ✓ All groom-first (reindexed)
- DEV: ❌ Mixed (some bride-first, some groom-first) — **Not safe to search!**
- Rest: ❌ All bride-first (not touched yet)

### Why It Happened

Task crashed or was killed mid-county. Partial data causes inconsistency in user-facing search results.

### How to Fix It

**Step 1: Identify Incomplete Counties**

```bash
mongosh myopicvicar_production

# Find counties with MIXED bride/groom order (dangerous)
> mixed = db.aggregate([
  { $match: { record_type: 'ma' } },
  { $group: { _id: '$county_code', roles: { $addToSet: '$transcript_names.0.role' } } },
  { $match: { roles: { $size: 2 } } }  // Has BOTH 'g' and 'b'
])
> mixed.toArray()  // Shows counties with mixed order

# Find counties NOT YET REINDEXED (all bride-first)
> not_reindexed = db.search_records.distinct('county_code', { 'transcript_names.0.role': 'b' })
> not_reindexed.sort()
```

**Step 2: Decide: Restart Incomplete County or Continue?**

**Option A: Reindex the Incomplete County Again**
```bash
# Re-run reindex for DEV (will fix mixed state)
time bundle exec rake freereg:reprocess_batches_for_a_county[DEV]

# Verify fixed
mongosh myopicvicar_production
> db.search_records.countDocuments({ county_code: 'DEV', 'transcript_names.0.role': 'g' })
# Should == total DEV marriage records
```

**Option B: Clear Mixed Records and Start Over**
```bash
# ⚠️ DESTRUCTIVE: Delete all DEV marriage records and reimport
# Only do this if you have the original CSV files!

mongosh myopicvicar_production
> db.search_records.deleteMany({ county_code: 'DEV', record_type: 'ma' })
> db.freereg1_csv_entries.deleteMany({ county_code: 'DEV', record_type: 'ma' })

# Then reimport CSV files for DEV from source
# (This is outside the scope of reindex guide — contact your team lead)
```

**Step 3: Continue Reindexing Remaining Counties**

```bash
# After fixing incomplete counties, continue with not-yet-touched counties

not_reindexed = ["DOR", "DUR", "ESS", "GLS", ...]

for county in DOR DUR ESS GLS; do
  time bundle exec rake freereg:reprocess_batches_for_a_county[$county]
  sleep 10  # Brief pause between counties
done
```

### Prevention

- **Don't interrupt tasks**: If a task is running, don't kill it or interrupt unless absolutely necessary
- **Monitor progress**: Keep logs open in a separate terminal
- **Verify before continuing**: After each county, verify all records were updated before moving to next
- **Use a script**: Use a bash script (from [how-to-run-reindex.md](#step-4-repeat-for-remaining-counties)) that logs progress clearly

---

---

## Search Results Inconsistent

### Problem

You search for "John Smith" (groom). Sometimes you get results with John first, sometimes Jane first. Records are showing different orders.

### Why It Happened

Partial reindex (see section above). Some SearchRecords have groom-first, others have bride-first.

### How to Fix It

**Identify Mixed Records:**

```bash
mongosh myopicvicar_production

> // Count records with groom-first
> groom_first = db.search_records.countDocuments({ 
    record_type: 'ma',
    'transcript_names.0.role': 'g'
  })
  
> // Count records with bride-first
> bride_first = db.search_records.countDocuments({ 
    record_type: 'ma',
    'transcript_names.0.role': 'b'
  })
  
> console.log('Groom first:', groom_first, '\nBride first:', bride_first)

# If BOTH counts > 0, you have inconsistency
```

**Solution: Complete the Reindex**

See [Partial Reindex](#partial-reindex-some-counties-done-some-not) section above. Complete reindex of all incomplete counties.

---

---

## Memory/CPU Spike During Reindex

### Problem

While the Rake task runs, the server's memory or CPU jumps to 90%+. Rails is slow, searches timeout.

### Why It Happened

- **Large county**: Processing 500k+ records at once
- **No pagination**: Rake task loads all records into memory
- **Background jobs**: Other processes running simultaneously

### How to Fix It

**Option 1: Reduce Load (Immediate)**

```bash
# Pause the Rake task (don't kill, just suspend)
# Find the process ID
pid=$(pgrep -f "rake freereg:reprocess")
kill -STOP $pid

# Wait 30 seconds for memory to free
sleep 30

# Resume
kill -CONT $pid

# Monitor
watch -n 2 'ps aux | grep rake'
```

**Option 2: Scale Down (Next Time)**

- Run reindex during **off-peak hours** (2–4 AM when searches are low)
- Reduce **parallel jobs** if using parallel script

```bash
# Slower: Process 1 county at a time, wait between
for county in YKS SOM DEV; do
  time bundle exec rake freereg:reprocess_batches_for_a_county[$county]
  sleep 300  # Wait 5 minutes between counties for cooldown
done
```

**Option 3: Custom Batching (Advanced)**

If a single county is too large, split it into batches:

```bash
# Find total records in county
mongosh myopicvicar_production
> db.freereg1_csv_entries.countDocuments({ county_code: 'YKS', record_type: 'ma' })
# Example: 500,000 records

# Create custom task to reindex in batches of 10k
cat > lib/tasks/reindex_with_batching.rake << 'EOF'
namespace :freereg do
  task :reindex_with_batching, [:county_code, :batch_size] => :environment do |t, args|
    county = args.county_code
    batch_size = (args.batch_size || 10000).to_i
    
    files = Freereg1CsvFile.where(county_code: county, record_type: 'ma').no_timeout
    
    files.each do |file|
      entries = file.entries.no_timeout
      entries.each_with_index do |entry, index|
        SearchRecord.update_create_search_record(entry, file.search_record_version, file.place)
        
        if (index + 1) % batch_size == 0
          puts "Processed #{index + 1} entries, pause for cooldown..."
          sleep 10  # Cool down between batches
        end
      end
    end
  end
end
EOF

# Run with 10k batch size
time bundle exec rake freereg:reindex_with_batching[YKS,10000]
```

### Prevention

- **Monitor from start**: Have `top` open in a separate terminal
- **Reindex off-peak**: Schedule during low-traffic times
- **One county at a time**: Avoids overwhelming database
- **Plan ahead**: If a county is known to be huge (>200k records), allocate extra time

---

---

## Verification Failed: IDs Don't Match

### Problem

After reindex, you try to verify using a MongoDB query, but the IDs change or query fails:

```bash
mongosh myopicvicar_production

> // Before reindex
> before = db.search_records.findOne({ county_code: 'YKS', record_type: 'ma' })._id
> before  // ObjectId("5f3c0a...")

> // After reindex (expecting the same record)
> after = db.search_records.findOne({ county_code: 'YKS', record_type: 'ma' })._id
> after   // ObjectId("5f4e1b...") — DIFFERENT!
```

### Why It Happened

The query returned a **different record** because:
- Sorting isn't specified, so MongoDB returns random order
- Records were deleted/recreated (should not happen with `update_create_search_record`)
- Query is checking the wrong field

### How to Fix It

**Verify Using Freereg1CsvEntry Link (Safe Method):**

```bash
mongosh myopicvicar_production

> // Find a specific CSV entry
> entry = db.freereg1_csv_entries.findOne({ county_code: 'YKS', record_type: 'ma', groom_surname: 'Smith' })
> entry._id  // ObjectId("...")

> // Find its SearchRecord
> sr = db.search_records.findOne({ freereg1_csv_entry_id: entry._id })

> // Check order
> sr.transcript_names[0].role  // Should be 'g' (groom)
> sr.transcript_names[1].role  // Should be 'b' (bride)
```

This is safer because it follows the actual **relationship** between CSV entry and SearchRecord.

### Prevention

- **Use relationship queries**: Find SearchRecord via its freereg1_csv_entry_id
- **Specify sort**: If using random queries, add `.sort({ created_at: -1 }).limit(1)` to get most recent
- **Compare multiple records**: Check 5–10 records, not just one random record

---

---

## Everything is Completely Broken

### Problem

Multiple errors, partial data, inconsistent state. You're not sure what to do.

### Nuclear Option: Fresh Start (Not Recommended)

⚠️ **Only use this if:** You can re-import CSV files from source AND have team approval.

```bash
# Back up the database first!
mongodump --db myopicvicar_production --out /tmp/backup_before_reset

# Delete all marriage searchrecords (not recommended for production!)
mongosh myopicvicar_production
> db.search_records.deleteMany({ record_type: 'ma' })
> db.freereg1_csv_entries.deleteMany({ record_type: 'ma' })

# Re-import CSV files (this is a separate process, outside this guide)
# Contact your team lead for reimport procedure
```

### Ask for Help

Before doing anything drastic:

1. **Document the problem**: Run these diagnostics
   ```bash
   # Save diagnostic output
   mongosh myopicvicar_production --eval "
     printjson(db.search_records.aggregate([
       { \$match: { record_type: 'ma' } },
       { \$group: { _id: '\$county_code', 
                    groom_first: { \$sum: { \$cond: [{ \$eq: ['\$transcript_names.0.role', 'g'] }, 1, 0] } },
                    bride_first: { \$sum: { \$cond: [{ \$eq: ['\$transcript_names.0.role', 'b'] }, 1, 0] } }
                  } },
       { \$sort: { _id: 1 } }
     ]).toArray())
   " > /tmp/reindex_status.json
   ```

2. **Share findings**: Post diagnostics to your team's Slack/email

3. **Consult**: Talk to the team lead who knows the full data workflow

---

---

## Quick Reference: Common Fixes

| Issue | Quick Fix | Link |
|-------|-----------|------|
| Task hangs forever | Wait longer, monitor DB load, or kill and resume | [Task Hangs or Times Out](#task-hangs-or-times-out) |
| transcript_names didn't change | Deploy code, check database/county | [transcript_names Unchanged](#transcriptnames-unchanged-after-reindex) |
| "No such file or directory" | Use `bundle exec`, check PWD, verify file exists | [Rake Task Fails](#rake-task-fails-no-such-file-or-directory) |
| MongoDB connection error | Check if MongoDB running, verify MONGO_URL | [Database Connection Error](#database-connection-error) |
| Partial reindex (mixed order) | Rerun incomplete counties | [Partial Reindex](#partial-reindex-some-counties-done-some-not) |
| Search results inconsistent | Complete the reindex | [Search Results Inconsistent](#search-results-inconsistent) |
| Memory/CPU spike | Pause task, reduce load, run off-peak | [Memory/CPU Spike](#memorycpu-spike-during-reindex) |

---

## When to Escalate

Contact your team lead if:
- ✅ Database corruption suspected
- ✅ Cannot regain consistency after trying fixes
- ✅ Need to re-import CSV files from source
- ✅ Multiple counties affected by errors
- ✅ Business impact required (search downtime, etc.)

---

## Next Steps

- **Issue fixed?** Jump back to [how-to-run-reindex.md](how-to-run-reindex.md#phase-2-production-county-by-county)
- **Still unclear?** Jump to [why-it-works.md](why-it-works.md) for deeper understanding
- **Need visuals?** Jump to [diagrams.mmd](diagrams.mmd)
