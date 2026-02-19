# app/services/csvfile_batch_processing_runner.rb
class CsvfileBatchProcessingRunner
  BatchProcessingResult = Struct.new(
    :was_processed,  # Boolean: did we actually send the batch for processing?
    :message,        # String: human-friendly explanation for the user
    :trace_id,       # String: unique identifier for this run
    :error,          # Exception or nil
    keyword_init: true
  )

  def process_batch(csvfile:, user:)
    trace_id  = SecureRandom.uuid
    timestamp = Time.current

    begin
      proceed = csvfile.check_for_existing_file_and_save
      csvfile.save if proceed

      if csvfile.errors.any?
        message = "The upload with file name #{csvfile.file_name} was unsuccessful because #{csvfile.errors.messages}"
        return failure_result(
          message: message,
          csvfile: csvfile,
          user: user,
          trace_id: trace_id,
          timestamp: timestamp
        )
      end

      template_set = MyopicVicar::Application.config.template_set

      if template_set == "freecen"
        csvfile.rename_extention
      end

      batch = csvfile.create_batch_unless_exists
      range = File.join(csvfile.userid, csvfile.file_name)

      if batch_already_waiting_for_processing?(csvfile)
        message = "Your file is already waiting to be processed. It cannot be reprocessed until that one is finished"
        return failure_result(
          message: message,
          csvfile: csvfile,
          user: user,
          trace_id: trace_id,
          timestamp: timestamp
        )
      end

      size = csvfile.estimate_size

      if size.blank? || (size.present? && size < 100)
        message = "The file #{csvfile.file_name} either does not exist or is too small to be a valid file."
        csvfile.clean_up

        return failure_result(
          message: message,
          csvfile: csvfile,
          user: user,
          trace_id: trace_id,
          timestamp: timestamp
        )
      end

      processing_time = csvfile.estimate_time

      case template_set
      when "freereg"
        handle_freereg_processing(
          csvfile: csvfile,
          user: user,
          batch: batch,
          range: range,
          processing_time: processing_time,
          trace_id: trace_id,
          timestamp: timestamp
        )
      when "freecen"
        handle_freecen_processing(
          csvfile: csvfile,
          batch: batch,
          range: range,
          trace_id: trace_id,
          timestamp: timestamp
        )
      else
        message = "Unknown template set '#{template_set}' while processing batch for file #{csvfile.file_name}."
        failure_result(
          message: message,
          csvfile: csvfile,
          user: user,
          trace_id: trace_id,
          timestamp: timestamp
        )
      end
    rescue StandardError => error
      failure_result(
        message: "An unexpected error occurred while processing the CSV batch. Please contact your coordinator.",
        csvfile: csvfile,
        user: user,
        trace_id: trace_id,
        timestamp: timestamp,
        error: error
      )
    end
  end

  def batch_already_waiting_for_processing?(csvfile)
    PhysicalFile.where(
      userid: csvfile.userid,
      file_name: csvfile.file_name,
      waiting_to_be_processed: true
    ).exists?
  end

  def handle_freereg_processing(csvfile:, user:, batch:, range:, processing_time:, trace_id:, timestamp:)
    if user.person_role == "trainee"

      Rails.logger.info "[CSVfile Batch Processing Runner] trainee: spawn rake build:freereg_new_update"
      Kernel.spawn(
        "rake build:freereg_new_update[\"no_search_records\",\"individual\",\"no\",#{range}]"
      )

      message = "The csv file #{csvfile.file_name} is being checked. You will receive an email when it has been completed."

      BatchProcessingResult.new(
        was_processed: true,
        message: message,
        trace_id: trace_id,
        error: nil
      )
    elsif processing_time < Csvfile::PROCESSING_TIME_THRESHOLD
      batch.update_attributes(
        waiting_to_be_processed: true,
        waiting_date: Time.current
      )

      processor_initiation_lock_file =
        File.join(Rails.root, "tmp", "processor_initiation_lock_file.txt")

      File.new(processor_initiation_lock_file, "w") unless File.exist?(processor_initiation_lock_file)
      Rails.logger.info "[CSVfile Batch Processing Runner] processor initiation lock set"

      Rails.logger.info "[CSVfile Batch Processing Runner] spawn rake build:freereg_new_update"
      Kernel.spawn(
        "rake build:freereg_new_update[\"create_search_records\",\"waiting\",\"no\",\"a-9\"]"
      )

      message = "The csv file #{csvfile.file_name} is being processed. You will receive an email when it has been completed."

      BatchProcessingResult.new(
        was_processed: true,
        message: message,
        trace_id: trace_id,
        error: nil
      )
    else
      batch.destroy

      message = "Your file #{csvfile.file_name} is not being processed in its current form as it is too large. " \
                "Your coordinator and the data managers have been informed. Please discuss with them how to proceed."

      UserMailer.report_to_data_manger_of_large_file(
        csvfile.file_name,
        csvfile.userid
      ).deliver_now

      failure_result(
        message: message,
        csvfile: csvfile,
        user: user,
        trace_id: trace_id,
        timestamp: timestamp
      )
    end
  end

  def handle_freecen_processing(csvfile:, batch:, range:, trace_id:, timestamp:)
    batch.update_attributes(
      waiting_to_be_processed: true,
      waiting_date: Time.current
    )

    Rails.logger.warn(
      "FREECEN:CSV_PROCESSING: Starting rake task for userid=#{csvfile.userid} file_name=#{csvfile.file_name}"
    )

    pid = Kernel.spawn(
      "rake build:freecen_csv_process[\"no_search_records\",\"individual\",\"no\",\"#{range}\",\"'Modern'\",\"#{csvfile.type_of_processing}\"]"
    )

    Rails.logger.warn(
      "FREECEN:CSV_PROCESSING: rake task pid=#{pid} trace_id=#{trace_id}"
    )

    message = "The csv file #{csvfile.file_name} is being checked. You will receive an email when it has been completed."

    BatchProcessingResult.new(
      was_processed: true,
      message: message,
      trace_id: trace_id,
      error: nil
    )
  end

  def failure_result(message:, csvfile:, user:, trace_id:, timestamp:, error: nil)
    log_failure(
      message: message,
      csvfile: csvfile,
      user: user,
      trace_id: trace_id,
      timestamp: timestamp,
      error: error
    )

    BatchProcessingResult.new(
      was_processed: false,
      message: message,
      trace_id: trace_id,
      error: error
    )
  end

  def log_failure(message:, csvfile:, user:, trace_id:, timestamp:, error:)
    Rails.logger.error(
      "[CsvfileBatchProcessingRunner] " \
      "timestamp=#{timestamp.iso8601} " \
      "trace_id=#{trace_id} " \
      "userid=#{csvfile&.userid} " \
      "file_name=#{csvfile&.file_name} " \
      "user_id=#{user&.id} " \
      "message=#{message} " \
      "error_class=#{error&.class} " \
      "error_message=#{error&.message}"
    )
  end
end
