class Csv::ProjectActivationLoop
  # DEFAULT_SLEEP_SECONDS = 300
  DEFAULT_SLEEP_SECONDS = 30

  def self.call(create_search_records:, type:, force:, range:, trace_id: SecureRandom.uuid,
                logger: Rails.logger, sleeper: ->(seconds) { sleep(seconds) },
                lock: Csv::RakeFileLock.new)
    new(
      create_search_records: create_search_records,
      type:                  type,
      force:                 force,
      range:                 range,
      trace_id:              trace_id,
      logger:                logger,
      sleeper:               sleeper,
      lock:                  lock
    ).run
  end

  def initialize(create_search_records:, type:, force:, range:, trace_id:, logger:, sleeper:, lock:)
    @create_search_records = create_search_records
    @type                  = type
    @force                 = force
    @range                 = range
    @trace_id              = trace_id
    @logger                = logger
    @sleeper               = sleeper
    @lock                  = lock

    @iterations            = 0

    # you can inject this too; keeping it here as a first step
    @initiation_lock_file_path = Rails.root.join('tmp/processor_initiation_lock_file.txt')
  end

  def run
    @started_at = Time.now
    log_info "Starting CSV project activation loop at #{@started_at}"

    begin
      @lock.lock

      while PhysicalFile.waiting.exists?
        @iterations += 1
        log_info "Activation iteration #{@iterations} starting"
        
        # activate_once
        @sleeper.call(DEFAULT_SLEEP_SECONDS) # debug pause, remove when done

        log_info "Activation iteration #{@iterations} finished"
        @sleeper.call(DEFAULT_SLEEP_SECONDS)
      end

    rescue => e
      @ended_at = Time.now
      @elapsed_seconds = @ended_at - @started_at

      log_error "Activation loop failed at #{@ended_at} after #{@elapsed_seconds.round(2)}s: #{e.class} - #{e.message}"

      return Result.new(
        trace_id:        @trace_id,
        iterations:      @iterations,
        errors:          [e],
        started_at:      @started_at,
        ended_at:        @ended_at,
        elapsed_seconds: @elapsed_seconds
      )

    ensure
      @lock.unlock
      @lock.cleanup
      cleanup_initiation_lock_file
    end

    @ended_at = Time.now
    @elapsed_seconds = @ended_at - @started_at

    log_info "CSV project activation loop completed at #{@ended_at}; " \
             "iterations=#{@iterations}; elapsed=#{@elapsed_seconds.round(2)}s"

    Result.new(
      trace_id:        @trace_id,
      iterations:      @iterations,
      errors:          [],
      started_at:      @started_at,
      ended_at:        @ended_at,
      elapsed_seconds: @elapsed_seconds
    )
  end

  # -------------------------
  # Rich Result Object (inner)
  # -------------------------
  class Result
    attr_reader :trace_id, :iterations, :errors,
                :started_at, :ended_at, :elapsed_seconds

    def initialize(trace_id:, iterations:, errors:, started_at:, ended_at:, elapsed_seconds:)
      @trace_id        = trace_id
      @iterations      = iterations.to_i
      @errors          = Array(errors).compact
      @started_at      = started_at
      @ended_at        = ended_at
      @elapsed_seconds = elapsed_seconds
    end

    def success?
      @errors.empty?
    end

    def failure?
      !success?
    end

    def any_iterations?
      @iterations > 0
    end

    def error_messages
      @errors.map(&:message)
    end
  end

  private

  def activate_once
    NewFreeregCsvUpdateProcessor.activate_project(
      @create_search_records,
      @type,
      @force,
      @range
    )
  end

  def cleanup_initiation_lock_file
    return unless File.exist?(@initiation_lock_file_path)

    log_info "CSV_PROCESSING: Removing Initiation lock file"
    File.open(@initiation_lock_file_path, 'r') { |f| f.close }
    FileUtils.rm_f(@initiation_lock_file_path)
  end

  def log_info(message)
    @logger.info(log_prefix(message))
  end

  def log_error(message)
    @logger.error(log_prefix(message))
  end

  def log_prefix(message)
    "[trace_id=#{@trace_id}] [csv_project_activation_loop] #{message}"
  end
end
