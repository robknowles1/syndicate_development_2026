module Admin
  class AccountsController < BaseController
    def edit
      @admin_user = current_admin
    end

    def update
      @admin_user = current_admin

      # Require the current password even though the admin is already signed in: it
      # stops an unattended logged-in session from being turned into a permanent one.
      unless @admin_user.authenticate(submitted_admin_user_params[:current_password])
        @admin_user.errors.add(:current_password, I18n.t("admin.account.current_password_incorrect"))
        return render :edit, status: :unprocessable_entity
      end

      if @admin_user.change_password(password_params)
        # Changing the password rotates the salt, which invalidates outstanding reset and
        # invitation links and every other session for this account. Re-establish this one
        # so the admin who made the change is not logged out by it.
        sign_in_and_redirect(@admin_user, notice: I18n.t("admin.account.updated"))
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def password_params
      submitted_admin_user_params.permit(:password, :password_confirmation)
    end
  end
end
