class ApplicationController < ActionController::Base

  def healthcheck
    head :ok, content_type: "text/html"
  end

  helper_method :current_user

  private

    def current_user
      @current_user ||= session[:user] if session[:user]
    end

    def login_required
      unless current_user
        flash[:notice] = "Please sign in"
        redirect_to new_session_path
      end
    end

end
