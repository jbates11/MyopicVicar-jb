class FileProcessLock
  Result = Struct.new(:acquired, :trace_id, :path, keyword_init: true) do
    def acquired?
      acquired
    end

    def failed?
      !acquired
    end
  end

  def self.call(name:, logger: Rails.logger)
    new(name: name, logger: logger).call
  end

  def initialize(name:, logger:)
    @name     = name
    @logger   = logger
    @trace_id = SecureRandom.hex(8)
    @file     = nil
  end

  def call
    acquire
  end

  # -----------------------------
  # PUBLIC API
  # -----------------------------

  def acquire
    @file = File.open(lock_path, "w")

    if @file.flock(File::LOCK_EX | File::LOCK_NB)
      log("acquired lock")
      Result.new(acquired: true, trace_id: @trace_id, path: lock_path)
    else
      log("failed to acquire lock")
      Result.new(acquired: false, trace_id: @trace_id, path: lock_path)
    end

  rescue => e
    log("error acquiring lock: #{e.class}: #{e.message}")
    Result.new(acquired: false, trace_id: @trace_id, path: lock_path)
  end

  def release
    return unless @file

    @file.flock(File::LOCK_UN)
    @file.close
    @file = nil

    log("released lock")
  end

  # -----------------------------
  # INTERNALS
  # -----------------------------

  private

  def lock_path
    Rails.root.join("tmp", "#{@name}.lock").to_s
  end

  def log(message)
    @logger.info("[FileProcessLock][#{@name}][#{@trace_id}] #{message}")
  end
end
