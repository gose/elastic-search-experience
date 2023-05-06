class ApplicationController < ActionController::Base

  before_action :init_site

  def healthcheck
    head :ok, content_type: "text/html"
  end

  helper_method :current_user, :admin?

  private

    def init_site
      if cookies.encrypted[:logo] == 'custom'
        @logo = 'logo.png'
      else
        @logo = 'elastic-logo.png'
      end
    end

    def current_user
      @current_user ||= session[:user] if session[:user]
    end

    def admin?
      current_user && @current_user == 'admin'
    end

    def login_required
      unless current_user
        flash[:notice] = "Please sign in"
        redirect_to new_session_path
      end
    end

    def admin_required
      unless admin?
        flash[:notice] = "Not Authorized"
        redirect_to root_path
      end
    end
end
