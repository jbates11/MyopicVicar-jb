# frozen_string_literal: true

class MessageBuilderService
  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------
  def initialize(
    appname:,
    userid:,
    file_name:,
    raw_message:,
    batch_result:,
    county_result:,
    eligibility_result:
  )
    @appname            = appname.to_s.downcase
    @userid             = userid
    @file_name          = file_name
    @raw_message        = raw_message.to_s
    @batch_result       = batch_result
    @county_result      = county_result
    @eligibility_result = eligibility_result

    @message            = @raw_message.dup
    @subject            = ""
    @matches_county_group = false
  end

  def call
    case @appname
    when "freereg"
      build_freereg_message
    when "freecen"
      build_freecen_message
    else
      build_default_message
    end

    OpenStruct.new(
      subject: @subject,
      message: @message,
      matches_county_group: @matches_county_group
    )
  end

  # ---------------------------------------------------------------------------
  # Internal workflow
  # ---------------------------------------------------------------------------
  private

  # ---------------------------------------------------------------------------
  # FREEREG MESSAGE LOGIC
  # ---------------------------------------------------------------------------
  def build_freereg_message
    file_county = @county_result.chapman_code
    user_groups = @userid&.county_groups || []

    if user_groups.include?(file_county)
      @matches_county_group = true
      build_freereg_normal_subject
    else
      @matches_county_group = false
      build_freereg_cross_county_subject
      prepend_alert("ALERT! This file was uploaded to your county by userid: #{@userid.userid} from a county group not associated with your county.")
    end

    unless @eligibility_result.eligible
      prepend_alert("ALERT! You are getting this email because userid: #{@userid.userid} does not have a valid email address")
      # prepend_alert("ALERT! #{@eligibility_result.reason}")
    end
  end

  def build_freereg_normal_subject
    errors  = @batch_result.errors || 0
    datemin = @batch_result.datemin.to_s
    datemax = @batch_result.datemax.to_s

    @subject =
      "#{@userid.userid}/#{@file_name} processed with #{errors} errors over period #{datemin}-#{datemax}"
  end

  def build_freereg_cross_county_subject
    @subject =
      "* * * ALERT! Data was uploaded to your county from: #{@userid.userid}/#{@file_name}. * * *"
  end

  # ---------------------------------------------------------------------------
  # FREECEN MESSAGE LOGIC
  # ---------------------------------------------------------------------------
  def build_freecen_message
    @subject = "#{@userid.userid} processed #{@file_name} at #{Time.current}"
  end

  # ---------------------------------------------------------------------------
  # DEFAULT MESSAGE LOGIC
  # ---------------------------------------------------------------------------
  def build_default_message
    @subject = "Batch #{@file_name} processed"
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------
  def prepend_alert(text)
    @message = "<p>#{text}</p>" + @message
  end
end
