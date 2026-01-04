class FreeregCsvUpdateTaskRunner
  FreeregCsvUpdateResult = Struct.new(
    :was_executed,   # Boolean: did the task run?
    :message,        # String: user/system-facing message
    :trace_id,       # String: unique identifier for this run
    :error,          # Exception or nil
    keyword_init: true
  )

  def run_rake_equivalent(search_record:, type:, force:, range:)
    trace_id  = SecureRandom.uuid
    timestamp = Time.current

    begin
      load_processor
      load_mongoid

      log_start(
        search_record: search_record,
        type: type,
        force: force,
        range: range,
        trace_id: trace_id,
        timestamp: timestamp
      )

      if type == "individual"
        return run_individual_project(
          search_record: search_record,
          type: type,
          force: force,
          range: range,
          trace_id: trace_id
        )
      end

      if processing_lock_exists?
        return handle_existing_lock(
          search_record: search_record,
          type: type,
          force: force,
          range: range,
          trace_id: trace_id
        )
      end

      start_new_range_processing(
        search_record: search_record,
        type: type,
        force: force,
        range: range,
        trace_id: trace_id
      )

    rescue Exception => error
      return handle_failure(
        message: "FREEREG:CSV_PROCESSING: An unexpected error occurred.",
        trace_id: trace_id,
        timestamp: timestamp,
        error: error
      )
    end
  end

  # ------------------------------------------------------------------
  # Core Steps
  # ------------------------------------------------------------------

  def load_processor
    require "new_freereg_csv_update_processor"
  end

  def load_mongoid
    Mongoid.load!(Rails.root.join("config", "mongoid.yml"))
  end

  def processing_lock_path
    Rails.root.join("tmp", "processing_rake_lock_file.txt")
  end

  def initiation_lock_path
    Rails.root.join("tmp", "processor_initiation_lock_file.txt")
  end

  def processing_lock_exists?
    File.exist?(processing_lock_path)
  end

  # ------------------------------------------------------------------
  # Individual Processing
  # ------------------------------------------------------------------

  def run_individual_project(search_record:, type:, force:, range:, trace_id:)
    NewFreeregCsvUpdateProcessor.activate_project(search_record, type, force, range)

    FreeregCsvUpdateResult.new(
      was_executed: true,
      message: "FREEREG:CSV_PROCESSING: Individual project executed.",
      trace_id: trace_id,
      error: nil
    )
  end

  # ------------------------------------------------------------------
  # Existing Lock Handling
  # ------------------------------------------------------------------

  def handle_existing_lock(search_record:, type:, force:, range:, trace_id:)
    puts "FREEREG:CSV_PROCESSING: Lock file exists — checking status"

    locked = NewFreeregCsvUpdateProcessor.check_file_lock_status

    unless locked.present?
      return FreeregCsvUpdateResult.new(
        was_executed: false,
        message: "FREEREG:CSV_PROCESSING: Lock file exists but no active lock — exiting.",
        trace_id: trace_id,
        error: nil
      )
    end

    NewFreeregCsvUpdateProcessor.process_activate_project(search_record, type, force, range)

    FreeregCsvUpdateResult.new(
      was_executed: true,
      message: "FREEREG:CSV_PROCESSING: Lock confirmed — continuing processing.",
      trace_id: trace_id,
      error: nil
    )
  end

  # ------------------------------------------------------------------
  # New Range Processing
  # ------------------------------------------------------------------

  def start_new_range_processing(search_record:, type:, force:, range:, trace_id:)
    puts "FREEREG:CSV_PROCESSING: No lock file — starting new range processing"

    NewFreeregCsvUpdateProcessor.create_rake_lock_file
    NewFreeregCsvUpdateProcessor.process_activate_project(search_record, type, force, range)

    FreeregCsvUpdateResult.new(
      was_executed: true,
      message: "FREEREG:CSV_PROCESSING: New range processing started.",
      trace_id: trace_id,
      error: nil
    )
  end

  # ------------------------------------------------------------------
  # Failure Handling
  # ------------------------------------------------------------------

  def handle_failure(message:, trace_id:, timestamp:, error:)
    log_failure(
      message: message,
      trace_id: trace_id,
      timestamp: timestamp,
      error: error
    )

    cleanup_lock_file(processing_lock_path)
    cleanup_lock_file(initiation_lock_path)

    FreeregCsvUpdateResult.new(
      was_executed: false,
      message: message,
      trace_id: trace_id,
      error: error
    )
  end

  def cleanup_lock_file(path)
    return unless File.exist?(path)

    file = File.open(path)
    file.close
    FileUtils.rm_f(file)
  end

  def log_start(search_record:, type:, force:, range:, trace_id:, timestamp:)
    puts "FREEREG:CSV_PROCESSING: Starting"
    puts "  timestamp=#{timestamp}"
    puts "  trace_id=#{trace_id}"
    puts "  search_record=#{search_record}"
    puts "  type=#{type}"
    puts "  force=#{force}"
    puts "  range=#{range}"
  end

  def log_failure(message:, trace_id:, timestamp:, error:)
    Rails.logger.error(
      "[FreeregCsvUpdateTaskRunner] " \
      "timestamp=#{timestamp.iso8601} " \
      "trace_id=#{trace_id} " \
      "message=#{message} " \
      "error_class=#{error.class} " \
      "error_message=#{error.message} " \
      "backtrace=#{error.backtrace.inspect}"
    )
  end
end
