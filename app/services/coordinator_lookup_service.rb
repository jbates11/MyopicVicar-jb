# frozen_string_literal: true

class CoordinatorLookupService
  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------
  def initialize(userid:, county:, syndicate_code:, appname:)
    @userid          = userid
    @county          = county
    @syndicate_code  = syndicate_code
    @appname         = appname.to_s.downcase
  end

  def call
    StructuredLogging.info(
      event: "coordinator_lookup_start",
      message: "Starting coordinator lookup",
      context: {
        userid: @userid&.userid,
        county: @county&.chapman_code,
        syndicate: @syndicate_code,
        appname: @appname
      }
    )

    # Priority order:
    # 1. County coordinator
    # 2. Syndicate coordinator
    # 3. Exec lead
    # 4. App-specific manager
    # 5. Hardcoded fallback

    lookup_county_coordinator ||
      lookup_syndicate_coordinator ||
      lookup_exec_lead ||
      lookup_app_manager ||
      fallback_result
  end

  # ---------------------------------------------------------------------------
  # Internal workflow
  # ---------------------------------------------------------------------------
  private

  # ---------------------------------------------------------------------------
  # COUNTY COORDINATOR
  # ---------------------------------------------------------------------------
  def lookup_county_coordinator
    return nil unless @county.present?

    coordinator_id = @county.county_coordinator
    return nil unless coordinator_id.present?

    coordinator = UseridDetail.where(userid: coordinator_id).first
    return nil unless valid_coordinator?(coordinator)

    StructuredLogging.info(
      event: "coordinator_lookup",
      message: "Using county coordinator",
      context: { coordinator: coordinator.userid }
    )

    build_result(coordinator, "county")
  end

  # ---------------------------------------------------------------------------
  # SYNDICATE COORDINATOR
  # ---------------------------------------------------------------------------
  def lookup_syndicate_coordinator
    return nil unless @syndicate_code.present?

    syndicate = Syndicate.where(syndicate_code: @syndicate_code).first
    return nil unless syndicate.present?

    coordinator_id = syndicate.syndicate_coordinator
    return nil unless coordinator_id.present?

    coordinator = UseridDetail.where(userid: coordinator_id).first
    return nil unless valid_coordinator?(coordinator)

    StructuredLogging.info(
      event: "coordinator_lookup",
      message: "Using syndicate coordinator",
      context: { coordinator: coordinator.userid }
    )

    build_result(coordinator, "syndicate")
  end

  # ---------------------------------------------------------------------------
  # EXEC LEAD (FR Exec Lead)
  # ---------------------------------------------------------------------------
  def lookup_exec_lead
    exec = UseridDetail.userid("FR Exec Lead").first
    return nil unless valid_coordinator?(exec)

    StructuredLogging.warn(
      event: "coordinator_lookup_fallback_exec",
      message: "Falling back to Exec Lead",
      context: { exec: exec.userid }
    )

    build_result(exec, "exec")
  end

  # ---------------------------------------------------------------------------
  # APP-SPECIFIC MANAGER (REGManager, CENManager)
  # ---------------------------------------------------------------------------
  def lookup_app_manager
    role_id =
      case @appname
      when "freereg" then "REGManager"
      when "freecen" then "CENManager"
      else nil
      end

    return nil unless role_id.present?

    manager = UseridDetail.userid(role_id).first
    return nil unless valid_coordinator?(manager)

    StructuredLogging.warn(
      event: "coordinator_lookup_fallback_manager",
      message: "Falling back to app manager",
      context: { manager: manager.userid, appname: @appname }
    )

    build_result(manager, "manager")
  end

  # ---------------------------------------------------------------------------
  # HARD FALLBACK
  # ---------------------------------------------------------------------------
  def fallback_result
    fallback_email = "Vinodhini Subbu <vinodhini.subbu@freeukgenealogy.org.uk>"

    StructuredLogging.error(
      event: "coordinator_lookup_hard_fallback",
      message: "No coordinator found — using hardcoded fallback",
      context: { fallback_email: fallback_email }
    )

    # AuditEvent.error(
    #   event: "coordinator_lookup_hard_fallback",
    #   message: "No coordinator found for user",
    #   pipeline_step: "coordinator_lookup",
    #   context: {
    #     userid: @userid&.userid,
    #     county: @county&.chapman_code,
    #     syndicate: @syndicate_code
    #   }
    # )

    OpenStruct.new(
      coordinator: nil,
      email: fallback_email,
      role: "fallback"
    )
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------
  def valid_coordinator?(user)
    user.present? &&
      user.active &&
      user.email_address_valid &&
      user.email_address.present?
  end

  def build_result(user, role)
    email = "#{user.person_forename} #{user.person_surname} <#{user.email_address}>"

    OpenStruct.new(
      coordinator: user,
      email: email,
      role: role
    )
  end
end
