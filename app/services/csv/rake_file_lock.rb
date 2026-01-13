class Csv::RakeFileLock
  attr_reader :path

  def initialize(path: Rails.root.join('tmp', 'processing_rake_lock_file.txt'),
                 logger: Rails.logger)
    @path   = path
    @logger = logger
    @file   = File.open(@path, 'w')
  end

  def lock
    @logger.info "CSV_PROCESSING: Locking rake lock file: #{@path}"
    @file.flock(File::LOCK_EX)
  end

  def unlock
    @logger.info "CSV_PROCESSING: Unlocking rake lock file: #{@path}"
    @file.flock(File::LOCK_UN)
  end

  def cleanup
    return unless File.exist?(@path)

    @logger.info "CSV_PROCESSING: Removing rake lock file #{@path}"
    @file.close
    FileUtils.rm_f(@path)
  end
end
