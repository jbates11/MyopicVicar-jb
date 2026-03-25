# frozen_string_literal: true

require 'app'
require 'chapman_code'
require 'fileutils'

desc 'FreeREG: backfill missing/empty embedded search_names (SearchRecord#transform); args chapman_codes[,limit[,fix]]; third arg fix to save; logs under log/'
task :backfill_missing_search_names, %i[chapman_codes limit fix] => :environment do |_t, args|
  unless App.name_downcase == 'freereg'
    puts "This task is for FreeREG only (current app: #{App.name_downcase}). Aborting."
    exit 1
  end

  fix = args.fix.to_s.strip == 'fix'
  chapman_codes_arg = args.chapman_codes.to_s.strip
  limit = args.limit.present? ? args.limit.to_i : 0
  skip_hint = ENV['BACKFILL_SEARCH_NAMES_NO_HINT'].to_s == '1'

  if chapman_codes_arg.blank?
    puts 'Provide chapman_codes: comma-separated list (e.g. CON,RUT) or all'
    exit 1
  end

  county_codes = if chapman_codes_arg == 'all'
                   ChapmanCode.values.uniq.compact
                 else
                   chapman_codes_arg.split(',').map(&:strip).reject(&:blank?)
                 end

  base_filters = lambda do |scoped|
    scoped
      .where(:freereg1_csv_entry_id.exists => true)
      # Match both "search_names does not exist" and "search_names is empty"
      # without using the expensive `search_names: []` equality form.
      .where('search_names.0' => { '$exists' => false })
      .where('transcript_names.0' => { '$exists' => true })
  end

  log_dir = Rails.root.join('log')
  FileUtils.mkdir_p(log_dir)
  log_path = log_dir.join('backfill_missing_search_names.log')
  log = File.open(log_path, 'a')
  log.puts "[#{Time.now.utc.iso8601}] start fix=#{fix} chapman_codes=#{chapman_codes_arg} counties=#{county_codes.size} limit=#{limit} hint=#{skip_hint ? 'off' : 'chapman_record_type'}"

  updated_log_path = log_dir.join('backfill_missing_search_names_updated.tsv')
  updated_log = nil
  if fix
    updated_log = File.open(updated_log_path, 'a')
    updated_log.puts "# run_at=#{Time.now.utc.iso8601} chapman_codes=#{chapman_codes_arg} limit=#{limit}"
    updated_log.puts %w[search_record_id chapman_code line_id freereg1_csv_entry_id].join("\t")
  end

  # Pre-counts can be expensive for `chapman_code` filters; apply the same hint we use for the cursor.
  safe_count = lambda do |scoped|
    begin
      scoped = scoped.hint('chapman_record_type') unless skip_hint
      scoped.count
    rescue StandardError => e
      if !skip_hint && e.message.to_s.match?(/hint|index|code 2|Bad hint/i)
        log.puts "count_hint_failed #{e.class}: #{e.message} (falling back to count without hint)"
        scoped.count
      else
        raise
      end
    end
  end

  total_matching = 0
  county_codes.each do |code|
    total_matching += safe_count.call(base_filters.call(SearchRecord.where(chapman_code: code)))
  end
  puts "Matching SearchRecords (sum by county): #{total_matching}"
  log.puts "matching_count=#{total_matching}"
  puts "Updated records will be appended to: #{updated_log_path}" if fix

  processed = 0
  fixed = 0
  errors = 0
  sample_shown = 0

  each_cursor_record = lambda do |relation|
    relation.each do |sr|
      break if limit.positive? && processed >= limit

      processed += 1

      if !fix && sample_shown < 25
        puts "#{sr.id}\t#{sr.chapman_code}\t#{sr.line_id}"
        sample_shown += 1
      end

      next unless fix

      begin
        sr.transform
        sr.digest = sr.cal_digest
        sr.save!
        fixed += 1
        entry_id = sr.freereg1_csv_entry_id
        row = [sr.id.to_s, sr.chapman_code.to_s, sr.line_id.to_s, entry_id.present? ? entry_id.to_s : ''].join("\t")
        updated_log&.puts(row)
      rescue StandardError => e
        errors += 1
        msg = "#{sr.id}\t#{e.class}\t#{e.message}"
        puts "ERROR\t#{msg}"
        log.puts "ERROR\t#{msg}"
      end

      next unless fix && (processed % 500).zero?

      puts "Processed #{processed} (#{fixed} saved, #{errors} errors)..."
    end
  end

  county_codes.each do |county_code|
    break if limit.positive? && processed >= limit

    scoped = base_filters.call(SearchRecord.where(chapman_code: county_code))
    county_count = safe_count.call(scoped)
    next if county_count.zero?

    puts "County #{county_code}: #{county_count} matching"

    cursor = scoped.no_timeout
    cursor = cursor.hint('chapman_record_type') unless skip_hint

    begin
      each_cursor_record.call(cursor)
    rescue StandardError => e
      if !skip_hint && e.message.to_s.match?(/hint|index|code 2|Bad hint/i)
        puts "Hint rejected (#{e.class}): #{e.message}. Set BACKFILL_SEARCH_NAMES_NO_HINT=1 or fix indexes; retrying county #{county_code} without hint."
        log.puts "hint_failed county=#{county_code} #{e.class}: #{e.message}"
        each_cursor_record.call(scoped.no_timeout)
      else
        raise
      end
    end
  end

  summary = "Done. processed=#{processed} fixed=#{fixed} errors=#{errors} (dry-run: #{!fix})"
  puts summary
  log.puts summary
  updated_log&.close
  log.close
end
