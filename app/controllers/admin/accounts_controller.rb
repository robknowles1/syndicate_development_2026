module Admin
  class AccountsController < BaseController
    def edit
      @admin_user = current_admin
    end

    def update
      @admin_user = current_admin

      # Require the current password even though the admin is already signed in: it
      # stops an unattended logged-in session from being turned into a permanent one.
      unless @admin_user.authenticate(params.dig(:admin_user, :current_password))
        @admin_user.errors.add(:current_password, I18n.t("admin.account.current_password_incorrect"))
        return render :edit, status: :unprocessable_entity
      end

      if @admin_user.update(password_params)
        # Changing the password rotates the salt, invalidating outstanding reset and
        # invitation links. Re-establish this session so the admin is not logged out.
        reset_session
        session[:admin_user_id] = @admin_user.id
        redirect_to admin_root_path, notice: I18n.t("admin.account.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def password_params
      params.require(:admin_user).permit(:password, :password_confirmation)
    end
  end
end
