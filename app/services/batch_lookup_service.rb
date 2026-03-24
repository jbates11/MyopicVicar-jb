# frozen_string_literal: true

class BatchLookupService
  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------
  def initialize(file_name:, userid:, appname:)
    @file_name = file_name
    @userid    = userid
    @appname   = appname.to_s.downcase
  end

  def call
    return fallback_result("Missing file name") unless @file_name.present?
    return fallback_result("Missing userid")     unless @userid.present?

    batch = lookup_batch

    if batch.present?
      success(batch)
    else
      fallback_result("Batch not found")
    end
  end

  # ---------------------------------------------------------------------------
  # Internal workflow
  # ---------------------------------------------------------------------------
  private

  # Determine which model to query based on appname
  def lookup_batch
    case @appname
    when "freereg"
      Freereg1CsvFile.where(file_name: @file_name, userid: @userid).first
    when "freecen"
      FreecenCsvFile.where(file_name: @file_name, userid: @userid).first
    else
      Rails.logger.warn("BatchLookupService: Unknown appname #{@appname.inspect}")
      nil
    end
  end

  # ---------------------------------------------------------------------------
  # Result builders
  # ---------------------------------------------------------------------------
  def success(batch)
    OpenStruct.new(
      found: true,
      batch: batch,
      county: batch.county,
      datemin: batch.datemin,
      datemax: batch.datemax,
      errors: batch.error,
      reason: nil
    )
  end

  def fallback_result(reason)
    OpenStruct.new(
      found: false,
      batch: nil,
      county: nil,
      datemin: nil,
      datemax: nil,
      errors: nil,
      reason: reason
    )
  end
end
