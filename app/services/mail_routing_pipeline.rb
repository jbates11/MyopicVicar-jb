# frozen_string_literal: true

class MailRoutingPipeline
  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------
  def initialize(message_path:, user:, batch_name:, appname:, dry_run: false)
    @message_path = message_path
    @user         = normalize_user(user)
    @batch_name   = batch_name
    @appname      = appname.to_s.downcase
    @dry_run      = dry_run
  end

  def call
    StructuredLogging.info(
      event: "pipeline_start",
      message: "Mail routing pipeline started",
      context: { batch: @batch_name, userid: @user&.userid, message_path: @message_path, appname: @appname, dry_run: @dry_run }
    )

    raw_message = load_message

    # 1. Batch lookup
    batch_result = BatchLookupService.new(
      file_name: @batch_name,
      userid: @user,
      appname: @appname
    ).call

    # 2. County lookup
    county_result = CountyLookupService.new(
      file_name: @batch_name,
      userid: @user,
      appname: @appname,
      batch_record: batch_result.batch
    ).call

    # 3. Coordinator lookup
    coordinator_result = CoordinatorLookupService.new(
      userid: @user,
      county: county_result.county,
      syndicate_code: @user&.syndicate,
      appname: @appname
    ).call

    # 4. Eligibility - Valid email address
    eligibility_result = EligibilityService.new(@user).call

    # 5. Build subject + message
    message_result = MessageBuilderService.new(
      appname: @appname,
      userid: @user,
      file_name: @batch_name,
      raw_message: raw_message,
      batch_result: batch_result,
      county_result: county_result,
      eligibility_result: eligibility_result
    ).call

    # 6. Routing (to/cc)
    routing = compute_routing(
      coordinator_result: coordinator_result,
      message_result: message_result,
      eligibility_result: eligibility_result
    )

    # 7. DryRun handling
    if @dry_run
      return dry_run_report(
        batch_result: batch_result,
        county_result: county_result,
        coordinator_result: coordinator_result,
        eligibility_result: eligibility_result,
        message_result: message_result,
        routing: routing
      )
    end

    # 8. Normal result
    OpenStruct.new(
      to: routing.to,
      cc: routing.cc,
      subject: message_result.subject,
      message: message_result.message,
      person_forename: routing.person_forename
    )
  end

  # ---------------------------------------------------------------------------
  # Convenience Helper for Rails Console, Admin UI, and Ops
  # ---------------------------------------------------------------------------
  def self.dry_run_for(userid:, batch_name:, appname:, message_path: nil)
    user = UseridDetail.where(userid: userid).first

    unless user
      raise ArgumentError, "No user found with userid=#{userid}"
    end

    # Auto-detect message file if not provided
    message_path ||= Dir[
      Rails.root.join("log", "#{userid.downcase}_member_update_messages_*.log")
    ].max

    unless message_path && File.exist?(message_path)
      raise ArgumentError, "Message file not found for #{userid}. Provide message_path manually."
    end

    new(
      message_path: message_path,
      user:         user,
      batch_name:   batch_name,
      appname:      appname,
      dry_run:      true
    ).call
  end

  # ---------------------------------------------------------------------------
  # Internal workflow
  # ---------------------------------------------------------------------------
  private

  def load_message
    File.read(@message_path)
  rescue StandardError => e
    StructuredLogging.error(
      event: "message_load_failure",
      message: "Failed to read message file",
      context: { error: e.message, path: @message_path }
    )
    ""
  end

  # ---------------------------------------------------------------------------
  # DryRun Report
  # ---------------------------------------------------------------------------
  def dry_run_report(batch_result:, county_result:, coordinator_result:, eligibility_result:, message_result:, routing:)
    # AuditEvent.info(
    #   event: "dry_run_pipeline",
    #   message: "Dry run executed successfully",
    #   pipeline_step: "pipeline",
    #   context: {
    #     userid: @user&.userid,
    #     batch: @batch_name,
    #     coordinator_role: coordinator_result.role,
    #     valid_email_address: eligibility_result.eligible,
    #     matches_county_group: message_result.matches_county_group
    #   }
    # )

    StructuredLogging.info(
      event: "dry_run_complete",
      message: "Dry run completed",
      context: { routing: routing }
    )

    OpenStruct.new(
      dry_run: true,
      batch: batch_result,
      county: county_result,
      coordinator: coordinator_result,
      valid_email_address: eligibility_result,
      message: message_result,
      routing: routing
    )
  end

  # ---------------------------------------------------------------------------
  # Routing Logic
  # ---------------------------------------------------------------------------
  def compute_routing(coordinator_result:, message_result:, eligibility_result:)
    if eligibility_result.eligible
      eligible_routing(coordinator_result, message_result)
    else
      ineligible_routing(coordinator_result)
    end
  end

  def eligible_routing(coordinator_result, message_result)
    user_email = build_friendly_email(
      @user.person_forename,
      @user.person_surname,
      @user.email_address
    )

    if message_result.matches_county_group
      to = user_email
      cc = [coordinator_result.email].compact.uniq
    else
      to = coordinator_result.email
      cc = [user_email].compact.uniq
    end

    OpenStruct.new(
      to: to,
      cc: cc,
      person_forename: @user.person_forename.to_s
    )
  end

  def ineligible_routing(coordinator_result)
    OpenStruct.new(
      to: coordinator_result.email,
      cc: [],
      person_forename: coordinator_result.coordinator&.person_forename.to_s
    )
  end

  def build_friendly_email(forename, surname, email)
    return nil unless email.present?
    "#{forename} #{surname} <#{email}>"
  end

  # ---------------------------------------------------------------------------
  # Normalize user is an UseridDetail object
  # ---------------------------------------------------------------------------
  def normalize_user(user)
    return user if user.is_a?(UseridDetail)
    return UseridDetail.where(userid: user).first if user.is_a?(String)

    nil
  end
end
