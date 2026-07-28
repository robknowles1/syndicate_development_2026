module Admin
  class PasswordResetsController < BaseController
    skip_before_action :require_admin

    before_action :set_admin_from_token, only: [ :edit, :update ]

    rate_limit to: 5, within: 15.minutes, only: :create,
      with: -> { redirect_to new_admin_password_reset_path, alert: I18n.t("admin.password_reset.too_many_requests") }

    def new
    end

    def create
      admin = AdminUser.find_by(email: params[:email])
      AdminMailer.password_reset(admin).deliver_now if admin&.active?

      # Always the same response whether or not the address exists, so this cannot be
      # used to enumerate which addresses have admin accounts.
      redirect_to admin_login_path, notice: I18n.t("admin.password_reset.sent")
    end

    def edit
    end

    def update
      if @admin_user.update(password_params)
        # The token derives from the password salt, so changing the password has already
        # invalidated this link. Sign in explicitly rather than leaving them at a form.
        reset_session
        session[:admin_user_id] = @admin_user.id
        redirect_to admin_root_path, notice: I18n.t("admin.password_reset.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_admin_from_token
      @token = params[:token]
      @admin_user = AdminUser.find_by_token_for(:password_reset, @token)

      return if @admin_user

      redirect_to new_admin_password_reset_path, alert: I18n.t("admin.password_reset.invalid_token")
    end

    def password_params
      params.require(:admin_user).permit(:password, :password_confirmation)
    end
  end
end
