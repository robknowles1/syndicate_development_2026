module Admin
  class InvitationsController < BaseController
    skip_before_action :require_admin

    before_action :set_admin_from_claimed_token, only: [ :edit, :update ]

    # Moves the token out of the URL and into the session, so it is logged once here rather
    # than on every subsequent request and never reaches the form action. Only a token that
    # resolves is stashed: this is an unauthenticated GET any visitor can hit, and stashing
    # it unread lets a stranger write several kilobytes of their choosing into the session
    # cookie of whoever follows the link.
    def claim
      return reject_claimed_token unless admin_from_invitation_token(params[:token])

      session[:invitation_token] = params[:token]
      redirect_to admin_edit_invitation_path
    end

    def edit
    end

    def update
      if @admin_user.accept_invitation(invitation_params.to_h)
        # reset_session inside sign_in also discards the stashed token, which is now spent.
        sign_in_and_redirect(@admin_user, notice: I18n.t("admin.invitation.accepted"))
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_admin_from_claimed_token
      @admin_user = admin_from_invitation_token(session[:invitation_token])
      return if @admin_user

      session.delete(:invitation_token)
      reject_claimed_token
    end

    # A token that has already been accepted no longer resolves, because acceptance changes
    # the password salt the token derives from. The pending check additionally refuses one
    # minted against an admin who was never invited.
    def admin_from_invitation_token(token)
      admin_user = AdminUser.find_by_token_for(:invitation, token)
      admin_user if admin_user&.invitation_pending?
    end

    def reject_claimed_token
      redirect_to admin_login_path, alert: I18n.t("admin.invitation.invalid_token")
    end

    def invitation_params
      params.require(:admin_user).permit(:password, :password_confirmation)
    end
  end
end
