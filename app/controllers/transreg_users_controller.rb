class TransregUsersController < ApplicationController
  skip_before_action :require_login
  skip_before_action :verify_authenticity_token
  def new
    logger.warn "FREEREG::USER Entered transreg session #{session[:userid_detail_id]}  cookie #{cookies[:userid_detail_id] }"
    if session[:userid_detail_id].nil? && cookies[:userid_detail_id].nil?
      render(:text => { "result" => "failure", "message" => "You are not authorised to use these facilities"}.to_xml({:root => 'login'}))
      return
    end
    @user = UseridDetail.id(session[:userid_detail_id]).first unless session[:userid_detail_id].nil?
    @user = UseridDetail.id(cookies[:userid_detail_id]).first if session[:userid_detail_id].nil?

    render(:text => { "result" => "Logged in", :userid_detail => @user.attributes}.to_xml({:dasherize => false, :root => 'login'}))

  end

  def index
  end

  def refreshuser
    p "refresher"
    @transcriber_id = params[:transcriberid]
    @user = UseridDetail.where(:userid => @transcriber_id).first
    if @user.nil? then
      render(:text => { "result" => "failure", "message" => "Invalid transcriber id"}.to_xml({:root => 'refresh'}))
    else
      render(:text => {"result" => "success", :userid_detail => @user.attributes}.to_xml({:dasherize => false, :root => 'refresh'}))
    end
  end

  # AUTHENTICATE - Authenticates a subscriber's userid and password
  #
  def authenticate
    p "authenticate"
    p params
    @transcriber_id = params[:transcriberid]
    @transcriber_password = params[:transcriberpassword]

    if session[:userid_detail_id].nil? && cookies[:userid_detail_id].nil?
      render(:text => { "result" => "failure", "message" => "You are not authorised to use these facilities"}.to_xml({:root => 'authentication'}))
      return
    end

    @user = UseridDetail.where(:userid => @transcriber_id).first

    if @user.nil? then
      p "Unknown User"
      render(:text => { "result" => "unknown_user" }.to_xml({:root => 'authentication'}))
    else
      p "Known Transcriber"
      password = Devise::Encryptable::Encryptors::Freereg.digest(@transcriber_password,nil,nil,nil)
      if password == @user.password then
        p "Password matches"
        render(:text => {"result" => "success", :userid_detail => @user}.to_xml({:dasherize => false, :root => 'authentication'}))
      else
        p "No match on Password"
        render(:text => { "result" => "no_match" }.to_xml({:root => 'authentication'}))
      end
    end
  end

end
