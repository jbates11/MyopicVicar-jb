# app/services/diff_printer_with_timing_and_anomalies.rb
class DiffPrinterWithTimingAndAnomalies
  # before_record: deep dup of original raw hash
  # after_record:  mutated raw hash after normalization
  # model_class:   Mongoid model used for dirty tracking (e.g., SearchRecord)
  # label:         identifier for logging (e.g., record ID)
  #
  # Returns:
  # {
  #   hash_diff: {},
  #   mongoid_diff: {},
  #   elapsed_ms: Float,
  #   anomalies: [String]
  # }
  #
  def self.generate(before_record, after_record, model_class, label: nil)
    start_time = Time.now
    anomalies = []

    # === HASH DIFF ===
    hash_diff = {}

    before_record.each do |k, v|
      if after_record[k] != v
        hash_diff[k] = { before: v, after: after_record[k] }
      end
    end

    after_record.each do |k, v|
      unless before_record.key?(k)
        hash_diff[k] = { before: nil, after: v }
      end
    end

    # === MONGOID DIRTY TRACKING DIFF ===
    mongoid_doc = model_class.instantiate(before_record)

    after_record.each do |k, v|
      setter = "#{k}="
      begin
        mongoid_doc.send(setter, v) if mongoid_doc.respond_to?(setter)
      rescue
        # ignore unmapped fields
      end
    end

    mongoid_diff = mongoid_doc.changes

    # === TIMING ===
    elapsed_ms = ((Time.now - start_time) * 1000).round(2)

    # === ANOMALY DETECTION ===

    # 1. Slow record
    anomalies << "Slow record: #{elapsed_ms}ms" if elapsed_ms > 10.0

    # 2. Large diff
    total_changes = hash_diff.length + mongoid_diff.length
    anomalies << "Large diff: #{total_changes} fields changed" if total_changes > 5

    # 3. Unexpected fields added
    unexpected_additions = after_record.keys - before_record.keys
    if unexpected_additions.any?
      anomalies << "Unexpected fields added: #{unexpected_additions.join(', ')}"
    end

    # 4. Type‑casting surprises
    mongoid_diff.each do |field, (before, after)|
      if before.class != after.class
        anomalies << "Type cast: #{field} changed from #{before.class} to #{after.class}"
      end
    end

    # 5. Missing required fields (example)
    %i[birth_place search_date].each do |required|
      if after_record[required].blank?
        anomalies << "Missing required field: #{required}"
      end
    end

    # === LOGGING (development only) ===
    if Rails.env.development?
      puts "\n=== DIFF REPORT #{label ? "(#{label})" : ""} ==="
      puts "Elapsed: #{elapsed_ms} ms"

      puts "\nHASH DIFF:"
      puts(hash_diff.any? ? hash_diff.ai : "none")

      puts "\nMONGOID DIFF:"
      puts(mongoid_diff.any? ? mongoid_diff.ai : "none")

      puts "\nANOMALIES:"
      puts(anomalies.any? ? anomalies.ai : "none")

      Rails.logger.info do
        "[DiffPrinterWithTimingAndAnomalies] #{label} elapsed=#{elapsed_ms}ms\n" \
        "HASH DIFF:\n#{hash_diff.ai}\n" \
        "MONGOID DIFF:\n#{mongoid_diff.ai}\n" \
        "ANOMALIES:\n#{anomalies.ai}"
      end
    end

    {
      hash_diff: hash_diff,
      mongoid_diff: mongoid_diff,
      elapsed_ms: elapsed_ms,
      anomalies: anomalies
    }
  end
end
