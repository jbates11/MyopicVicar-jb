module Build
  class FreeregUpdateRunner
    LOCK_FILE        = Rails.root.join("tmp/processing_rake_lock_file.txt")
    INIT_LOCK_FILE   = Rails.root.join("tmp/processor_initiation_lock_file.txt")

    def initialize(args)
      @search_record = args.search_record
      @type          = args.type
      @force         = args.force
      @range         = args.range
    end

    def run
      log "Starting freereg_new_update task"

      if individual_run?
        process_individual
      elsif lock_file_exists?
        process_with_existing_lock
      else
        process_with_new_lock
      end

    rescue => e
      handle_exception(e)
    end

    private

    # -----------------------------
    # Branching Logic
    # -----------------------------

    def individual_run?
      @type == "individual"
    end

    def lock_file_exists?
      File.exist?(LOCK_FILE)
    end

    # -----------------------------
    # Processing Paths
    # -----------------------------

    def process_individual
      log "Starting individual project"
      NewFreeregCsvUpdateProcessor.activate_project(@search_record, @type, @force, @range)
    end

    def process_with_existing_lock
      log "Lock file exists. Checking lock status"

      if NewFreeregCsvUpdateProcessor.check_file_lock_status.present?
        log "Lock is valid. Continuing processing"
        process_project
      else
        log "Lock file exists but is invalid. Exiting"
      end
    end

    def process_with_new_lock
      log "Creating new lock file"
      NewFreeregCsvUpdateProcessor.create_rake_lock_file
      process_project
    end

    def process_project
      NewFreeregCsvUpdateProcessor.process_activate_project(
        @search_record, @type, @force, @range
      )
    end

    # -----------------------------
    # Error Handling
    # -----------------------------

    def handle_exception(error)
      log "Exception encountered during rake task"
      log error.message
      log error.backtrace.join("\n")

      remove_lock_file(LOCK_FILE)
      remove_lock_file(INIT_LOCK_FILE)
    end

    # -----------------------------
    # Helpers
    # -----------------------------

    def remove_lock_file(path)
      return unless File.exist?(path)

      log "Removing lock file: #{path}"
      FileUtils.rm_f(path)
    end

    def log(message)
      puts "FREEREG:CSV_PROCESSING: #{message}"
      Rails.logger.info "FREEREG_update_runner: #{message}"
    end
  end
end
