class SearchRecordProcessor
  # Public API ---------------------------------------------------------------

  def self.call(record, normalize: false, logger: Rails.logger)
    new(record, normalize: normalize, logger: logger).call
  end

  # Constructor --------------------------------------------------------------

  def initialize(record, normalize:, logger:)
    @record    = record
    @normalize = normalize
    @logger    = logger
    @trace_id  = SecureRandom.uuid
  end

  # Execution ---------------------------------------------------------------

  def call
    log_start

    return build_result(:missing_id) unless record_id

    if entry_missing?
      delete_record
      return build_result(:deleted)
    end

    processed = normalize? ? normalize_record(@record) : @record
    build_result(:kept, processed)
  ensure
    log_finish
  end

  # Result Object -----------------------------------------------------------

  class Result
    attr_reader :id, :record, :status, :trace_id

    def initialize(id:, record:, status:, trace_id:)
      @id       = id
      @record   = record
      @status   = status
      @trace_id = trace_id
    end

    # Ruby 2.7‑compatible predicate methods
    def kept?
      status == :kept
    end

    def deleted?
      status == :deleted
    end

    def invalid?
      status == :missing_id
    end
  end

  private

  # Internal domain verbs ---------------------------------------------------

  def entry_missing?
    !SearchQuery.does_the_entry_exist?(@record)
  end

  def delete_record
    if (sr = SearchRecord.find_by(_id: record_id))
      sr.delete
      log("Deleted SearchRecord #{record_id}")
    end
  end

  def normalize_record(rec)
    if needs_birth_place?(rec)
      rec = SearchQuery.add_birth_place_when_absent(rec)
      log("Added missing birth_place for record #{rec.ai}")
    end

    if rec[:search_date].blank?
      rec = SearchQuery.add_search_date_when_absent(rec)
      log("Added missing search_date for record #{rec.ai}")
    end

    rec
  end

  def needs_birth_place?(rec)
    App.name.downcase == "freecen" && rec[:birth_place].blank?
  end

  # Helpers -----------------------------------------------------------------

  def record_id
    @record["_id"]&.to_s
  end

  def normalize?
    @normalize
  end

  # Logging -----------------------------------------------------------------

  def log_start
    log("[SearchRecordProcessor] Start processing SearchRecord #{record_id.inspect}")
  end

  def log_finish
    log("[SearchRecordProcessor] Finished processing SearchRecord #{record_id.inspect}\n")
  end

  def log(message)
    @logger.info("[#{@trace_id}] #{message}")
  end

  # Result builders ---------------------------------------------------------

  def build_result(status, processed_record = nil)
    Result.new(
      id:       record_id,
      record:   processed_record,
      status:   status,
      trace_id: @trace_id
    )
  end
end
