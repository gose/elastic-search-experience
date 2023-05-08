class PagesController < ApplicationController

  skip_before_action :verify_authenticity_token, only: [:preferences, :feedback]

  def auth
    if params[:login] == 'demo' &&
         params[:password] ==
           Rails.application.credentials.dig(:user, :password)
      reset_session
      session[:user] = 'demo'
      redirect_to root_path
    else
      redirect_to login_path,
                  notice: 'You entered an invalid login or password.'
    end
  end

  def logout
    session[:user] = nil
    reset_session
    redirect_to root_path
  end

  def preferences
    cookies.encrypted[:logo] = { value: params[:logo], expires: Time.now + 1.year }
  end

  def feedback
    login = params[:login]
    login = current_user if login.blank? && current_user
    FeedbackJob.perform_later(
      {
        timestamp: "#{Time.now.utc.iso8601}",
        session_id: "#{session.id}",
        message: "#{params[:message]}",
        email: "#{login}"
      }
    )
  end
end
