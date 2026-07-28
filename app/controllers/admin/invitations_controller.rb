module Admin
  class InvitationsController < BaseController
    skip_before_action :require_admin

    before_action :set_admin_from_token

    def edit
    end

    def update
      if @admin_user.accept_invitation(**invitation_params.to_h.symbolize_keys)
        reset_session
        session[:admin_user_id] = @admin_user.id
        redirect_to admin_root_path, notice: I18n.t("admin.invitation.accepted")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_admin_from_token
      @token = params[:token]
      @admin_user = AdminUser.find_by_token_for(:invitation, @token)

      # A token that has already been accepted no longer resolves, because acceptance
      # changes the password salt the token is derived from.
      return if @admin_user&.invitation_pending?

      redirect_to admin_login_path, alert: I18n.t("admin.invitation.invalid_token")
    end

    def invitation_params
      params.require(:admin_user).permit(:password, :password_confirmation)
    end
  end
end
