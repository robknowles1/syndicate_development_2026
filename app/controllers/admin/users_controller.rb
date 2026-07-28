module Admin
  class UsersController < BaseController
    def index
      @admin_users = AdminUser.order(:email)
    end

    def new
      @admin_user = AdminUser.new
    end

    def create
      result = InviteAdminUser.new(user_params[:email]).call
      @admin_user = result.admin_user

      case result.status
      when :invited
        redirect_to admin_users_path, notice: I18n.t("admin.users.invited", email: @admin_user.email)
      when :delivery_failed
        redirect_to new_admin_user_path, alert: I18n.t("admin.users.invitation_delivery_failed")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      admin_user = AdminUser.find(params[:id])

      # Removing anyone other than yourself implies a second admin exists, so this guard
      # is also what stops the last admin being removed.
      if admin_user == current_admin
        redirect_to admin_users_path, alert: I18n.t("admin.users.cannot_remove_self")
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
