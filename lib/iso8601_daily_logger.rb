class Iso8601DailyLogger < Logger
  def initialize(log_path)
    super(log_path)
    @log_path = log_path
    @date = current_date
  end

  def add(severity, message = nil, progname = nil, &block)
    rotate_if_needed
    super
  end

  private

  def rotate_if_needed
    return if current_date == @date

    @date = current_date
    rotate_log_file
  end

  def rotate_log_file
    timestamp = Time.now.utc.strftime("%Y-%m-%d")
    new_name = @log_path.sub(".log", "-#{timestamp}.log")

    # Move current log to timestamped file
    File.rename(@log_path, new_name) if File.exist?(@log_path)

    prune_old_logs(10)

    # Reopen the log file
    @logdev = Logger::LogDevice.new(@log_path)
  end

  def current_date
    Time.now.utc.strftime("%Y-%m-%d")
  end

  def prune_old_logs(days_to_keep)
    pattern = @log_path.sub(".log", "-*.log")
    logs = Dir.glob(pattern).sort.reverse
    logs[days_to_keep..]&.each { |file| File.delete(file) }
  end

end
