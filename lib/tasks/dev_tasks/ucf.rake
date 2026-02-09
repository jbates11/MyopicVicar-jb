namespace :ucf do

    # Task name: ucf:validate_ucf_lists
    # Arguments:
    #   limit       → how many Place records to check
    #   fix         → whether to automatically fix issues ("fix")
    #
    # Detect and fix stale UCF lists
    #   - detects orphaned file/record ID
    #   - finds location mismatches
    #   - can auto-fix issues
    #
    # Dry run
    # rake ucf:validate_ucf_lists[1000]
    #
    # Fix issues
    # rake ucf:validate_ucf_lists[0,fix]
    #
    # 

  desc "Validate UCF lists for consistency"
  task :validate_ucf_lists, [:limit, :fix] => [:environment] do |t, args|

    limit        = args.limit.to_i
    apply_fixes  = args.fix == "fix"
    issues       = []

    Place.data_present.limit(limit).each do |place|
      original_ucf = place.ucf_list || {}
      updated_ucf  = original_ucf.deep_dup
      changed      = false

      #
      # ---------------------------------------------------------
      # BATCH 1 — Collect all file IDs for this Place
      # ---------------------------------------------------------
      #
      file_ids = original_ucf.keys
      existing_files = Freereg1CsvFile.where(:id.in => file_ids).to_a
      existing_file_ids = existing_files.map { |f| f.id.to_s }.to_set

      #
      # ---------------------------------------------------------
      # BATCH 2 — Collect all record IDs for this Place
      # ---------------------------------------------------------
      #
      record_ids = original_ucf.values.flatten
      existing_records = SearchRecord.where(:id.in => record_ids).pluck(:id)
      existing_record_ids = existing_records.map(&:to_s).to_set

      #
      # ---------------------------------------------------------
      # CHECK 1 — Orphaned file IDs
      # ---------------------------------------------------------
      #
      file_ids.each do |file_id|
        unless existing_file_ids.include?(file_id)
          issues << {
            place_id: place.id.to_s,
            issue: "Orphaned file ID in ucf_list",
            file_id: file_id
          }

          if apply_fixes
            updated_ucf.delete(file_id)
            changed = true
          end
        end
      end

      #
      # ---------------------------------------------------------
      # CHECK 2 — Orphaned record IDs
      # ---------------------------------------------------------
      #
      updated_ucf.each do |file_id, ids|
        next unless ids.is_a?(Array)

        valid_ids = ids.select { |rid| existing_record_ids.include?(rid) }

        if valid_ids.size != ids.size
          (ids - valid_ids).each do |missing|
            issues << {
              place_id: place.id.to_s,
              issue: "Orphaned record ID",
              file_id: file_id,
              record_id: missing
            }
          end

          if apply_fixes
            updated_ucf[file_id] = valid_ids
            changed = true
          end
        end
      end

      #
      # ---------------------------------------------------------
      # CHECK 3 — File location mismatch
      # ---------------------------------------------------------
      #
      file_lookup = existing_files.index_by { |f| f.id.to_s }

      updated_ucf.keys.each do |file_id|
        file = file_lookup[file_id]
        next unless file

        file_loc  = [file.chapman_code, file.place]
        place_loc = [place.chapman_code, place.place_name]

        if file_loc != place_loc
          issues << {
            place_id: place.id.to_s,
            issue: "File location mismatch",
            file_id: file_id,
            file_place: "#{file.chapman_code}/#{file.place}",
            place: "#{place.chapman_code}/#{place.place_name}"
          }
        end
      end

      #
      # ---------------------------------------------------------
      # APPLY FIXES (single atomic update)
      # ---------------------------------------------------------
      #
      if apply_fixes && changed
        place.set(ucf_list: updated_ucf)
      end
    end

    #
    # ---------------------------------------------------------
    # WRITE REPORT
    # ---------------------------------------------------------
    #
    timestamp = Time.now.to_i
    path = "log/ucf_validation_#{timestamp}.json"

    File.write(path, JSON.pretty_generate(issues))
    puts "Found #{issues.size} issues. Report: #{path}"
  end

end