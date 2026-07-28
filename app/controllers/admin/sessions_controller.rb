module Admin
  class SessionsController < BaseController
    skip_before_action :require_admin

    rate_limit to: 10, within: 3.minutes, only: :create,
      with: -> { redirect_to admin_login_path, alert: I18n.t("admin.login.too_many_attempts") }

    def new
    end

    def create
      admin = AdminUser.find_by(email: params[:email])

      if admin&.authenticate(params[:password]) && admin.active?
        # Discard the pre-login session before granting privileges. Carrying it over
        # lets an attacker who fixed the session id beforehand ride the authenticated
        # session afterwards.
        reset_session
        session[:admin_user_id] = admin.id
        redirect_to admin_root_path
      else
        # One message for every failure, so the response cannot be used to distinguish a
        # real address from a wrong password or an unaccepted invitation.
        flash.now[:alert] = I18n.t("admin.login.invalid_credentials")
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      reset_session
      redirect_to admin_login_path
    end
  end
end
