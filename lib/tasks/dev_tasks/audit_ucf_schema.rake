namespace :audit do

  desc "Audit MongoDB for UCF schema consistency (collect all violations)"
  task ucf_schema: :environment do
    puts "Running UCF schema audit..."

    report = {
      freereg_wrong_type: [],
      freereg_bad_elements: [],
      place_wrong_type: [],
      place_bad_keys_or_values: [],
      place_bad_value_elements: []
    }

    # valid_record_id = ->(x) { x.is_a?(String) || x.is_a?(BSON::ObjectId) }
    valid_record_id = ->(x) { x.is_a?(BSON::ObjectId) }

    # ---------------------------------------------------------
    # 1. Freereg1CsvFile.ucf_list MUST be Array of record_ids
    # ---------------------------------------------------------
    Freereg1CsvFile.where(:ucf_list.exists => true).no_timeout.each do |file|
      ucf = file.ucf_list

      unless ucf.is_a?(Array)
        report[:freereg_wrong_type] << file.id.to_s
        next
      end

      unless ucf.all? { |x| valid_record_id.call(x) }
        report[:freereg_bad_elements] << file.id.to_s
      end
    end

    # ---------------------------------------------------------
    # 2. Place.ucf_list MUST be Hash with Array-of-record_ids
    # ---------------------------------------------------------
    Place.where(:ucf_list.exists => true).no_timeout.each do |place|
      ucf = place.ucf_list

      unless ucf.is_a?(Hash)
        report[:place_wrong_type] << place.id.to_s
        next
      end

      ucf.each do |key, value|
        unless key.is_a?(String) && value.is_a?(Array)
          report[:place_bad_keys_or_values] << place.id.to_s
          break
        end

        unless value.all? { |x| valid_record_id.call(x) }
          report[:place_bad_value_elements] << place.id.to_s
          break
        end
      end
    end

    # ---------------------------------------------------------
    # Print full report
    # ---------------------------------------------------------
    puts "\n=== UCF Schema Audit Report ==="
    puts "Freereg1CsvFile: ucf_list not Array: #{report[:freereg_wrong_type].size}"
    puts "Freereg1CsvFile: ucf_list contains invalid record_ids: #{report[:freereg_bad_elements].size}"
    puts "Place: ucf_list not Hash: #{report[:place_wrong_type].size}"
    puts "Place: ucf_list has non-String keys or non-Array values: #{report[:place_bad_keys_or_values].size}"
    puts "Place: ucf_list values contain invalid record_ids: #{report[:place_bad_value_elements].size}"

    puts "\nSample offending IDs:"
    report.each do |category, ids|
      puts "#{category}: #{ids.take(10).join(', ')}"
    end

    puts "\nFull JSON report:"
    puts JSON.pretty_generate(report)
  end


  desc "Generate repair plan for UCF schema violations (BSON-safe)"
  task ucf_repair_plan: :environment do
    puts "Generating UCF repair plan..."

    # valid_record_id = ->(x) { x.is_a?(String) || x.is_a?(BSON::ObjectId) }
    valid_record_id = ->(x) { x.is_a?(BSON::ObjectId) }

    plan = {
      freereg_wrong_type: [],
      freereg_bad_elements: [],
      place_wrong_type: [],
      place_bad_keys_or_values: [],
      place_bad_value_elements: []
    }

    # ---------------------------------------------------------
    # Freereg1CsvFile fixes
    # ---------------------------------------------------------
    Freereg1CsvFile.where(:ucf_list.exists => true).no_timeout.each do |file|
      ucf = file.ucf_list

      unless ucf.is_a?(Array)
        plan[:freereg_wrong_type] << {
          id: file.id.to_s,
          current_type: ucf.class.to_s,
          suggested_fix: "Replace ucf_list with Array<record_id>"
        }
        next
      end

      bad = ucf.reject { |x| valid_record_id.call(x) }
      if bad.any?
        plan[:freereg_bad_elements] << {
          id: file.id.to_s,
          bad_values: bad,
          suggested_fix: "Remove or convert invalid record_ids"
        }
      end
    end

    # ---------------------------------------------------------
    # Place fixes
    # ---------------------------------------------------------
    Place.where(:ucf_list.exists => true).no_timeout.each do |place|
      ucf = place.ucf_list

      unless ucf.is_a?(Hash)
        plan[:place_wrong_type] << {
          id: place.id.to_s,
          current_type: ucf.class.to_s,
          suggested_fix: "Replace ucf_list with Hash<String, Array<record_id>>"
        }
        next
      end

      ucf.each do |key, value|
        unless key.is_a?(String) && value.is_a?(Array)
          plan[:place_bad_keys_or_values] << {
            id: place.id.to_s,
            bad_key: key,
            bad_value: value,
            suggested_fix: "Ensure key is String and value is Array<record_id>"
          }
          next
        end

        bad = value.reject { |x| valid_record_id.call(x) }
        if bad.any?
          plan[:place_bad_value_elements] << {
            id: place.id.to_s,
            file_key: key,
            bad_values: bad,
            suggested_fix: "Remove or convert invalid record_ids"
          }
        end
      end
    end

    filename = "log/ucf_repair_plan_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
    File.write(filename, JSON.pretty_generate(plan))

    puts "\nRepair plan written to #{filename}"
  end

end