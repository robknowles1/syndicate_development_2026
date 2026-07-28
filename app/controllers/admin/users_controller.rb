module Admin
  class UsersController < BaseController
    def index
      @admin_users = AdminUser.order(:email)
    end

    def new
      @admin_user = AdminUser.new
    end

    def create
      @admin_user = AdminUser.new(user_params)
      # A placeholder the invitee never learns; they set a real one via the emailed
      # link. has_secure_password requires a password on create, so it cannot be blank.
      @admin_user.password = SecureRandom.base58(32)
      @admin_user.invited_at = Time.current

      if @admin_user.save
        AdminMailer.invitation(@admin_user).deliver_now
        redirect_to admin_users_path, notice: I18n.t("admin.users.invited", email: @admin_user.email)
      else
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      admin_user = AdminUser.find(params[:id])

      if admin_user == current_admin
        redirect_to admin_users_path, alert: I18n.t("admin.users.cannot_remove_self")
      elsif AdminUser.count <= 1
        # Belt and braces: the self check already covers the single-admin case, but this
        # holds even if that logic changes and prevents locking everyone out.
        redirect_to admin_users_path, alert: I18n.t("admin.users.cannot_remove_last")
      else
        admin_user.destroy
        redirect_to admin_users_path, notice: I18n.t("admin.users.removed", email: admin_user.email)
      end
    end

    private

    def user_params
      params.require(:admin_user).permit(:email)
    end
  end
end
