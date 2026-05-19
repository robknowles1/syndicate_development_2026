module Admin
  class SessionsController < BaseController
    skip_before_action :require_admin

    def new
    end

    def create
      admin = AdminUser.find_by(email: params[:email])
      if admin&.authenticate(params[:password])
        session[:admin_user_id] = admin.id
        redirect_to admin_root_path
      else
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
