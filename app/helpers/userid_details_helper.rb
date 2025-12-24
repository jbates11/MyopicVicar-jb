module UseridDetailsHelper
  def registered(userid)
    userid.password == Devise::Encryptable::Encryptors::Freereg.digest('temppasshope',nil,nil,nil) ? registered = "No" : registered = "Yes"
    registered
  end

  def active_user(status)
    result = 'Yes' if status
    result = 'No' unless status
    result
  end

  def coordinator_display(userid)
    syndicate_record = Syndicate.find_by(syndicate_code: userid.syndicate)
    coordinator_code = syndicate_record&.syndicate_coordinator
    coordinator_user = UseridDetail.find_by(userid: coordinator_code)

    unless coordinator_user.present?
      return '<span style="color: red;">Syndicate coordinator missing or unknown.</span>'.html_safe
    end

    full_name = "#{coordinator_user.person_forename} #{coordinator_user.person_surname}"
    formatted = "#{full_name} (#{coordinator_code})"

    formatted.html_safe
  end

  def list_userid_files
    case appname_downcase
    when 'freereg'
      link_to 'List Batches', by_userid_freereg1_csv_file_path(@userid), method: :get, class: 'btn   btn--small'
    when 'freecen'
      link_to 'List Batches', by_userid_freecen_csv_file_path(@userid), method: :get, class: 'btn   btn--small'
    end
  end
end
