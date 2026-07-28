module Admin
  class PasswordResetsController < BaseController
    skip_before_action :require_admin

    before_action :set_admin_from_claimed_token, only: [ :edit, :update ]

    # Keyed on the address rather than the IP: the cost here is an inbox full of reset
    # mail for one admin, which a handful of IPs can produce under a per-IP limit.
    rate_limit to: 5, within: 15.minutes, only: :create, name: "reset_per_account",
      by: -> { params[:email].to_s.strip.downcase },
      with: -> { redirect_to new_admin_password_reset_path, alert: I18n.t("admin.password_reset.too_many_requests") }

    rate_limit to: 20, within: 15.minutes, only: :create, name: "reset_per_ip",
      with: -> { redirect_to new_admin_password_reset_path, alert: I18n.t("admin.password_reset.too_many_requests") }

    def new
    end

    def create
      admin = AdminUser.find_by(email: params[:email])
      deliver_reset_link(admin) if admin&.active?

      # Always the same response whether or not the address exists, so this cannot be
      # used to enumerate which addresses have admin accounts.
      redirect_to admin_login_path, notice: I18n.t("admin.password_reset.sent")
    end

    # Moves the token out of the URL and into the session, so it is logged once here rather
    # than on every subsequent request and never reaches the form action. Only a token that
    # resolves is stashed: this is an unauthenticated GET any visitor can hit, and stashing
    # it unread lets a stranger write several kilobytes of their choosing into the session
    # cookie of whoever follows the link.
    def claim
      return reject_claimed_token unless AdminUser.find_by_token_for(:password_reset, params[:token])

      session[:password_reset_token] = params[:token]
      redirect_to admin_edit_password_reset_path
    end

    def edit
    end

    def update
      if @admin_user.reset_password(password_params.to_h)
        # The token derives from the password salt, so a successful reset spends this link.
        # Sign in explicitly rather than leaving them at a form they can no longer submit.
        # reset_session inside sign_in also discards the stashed token.
        sign_in_and_redirect(@admin_user, notice: I18n.t("admin.password_reset.updated"))
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def deliver_reset_link(admin)
      AdminMailer.password_reset(admin).deliver_now
    rescue StandardError => error
      # Letting this raise turns a delivery outage into a 500 for known addresses only,
      # which distinguishes them from unknown ones the response text is careful not to.
      Rails.error.report(error, handled: true)
    end

    def set_admin_from_claimed_token
      @admin_user = AdminUser.find_by_token_for(:password_reset, session[:password_reset_token])
      return if @admin_user

      session.delete(:password_reset_token)
      reject_claimed_token
    end

    def reject_claimed_token
      redirect_to new_admin_password_reset_path, alert: I18n.t("admin.password_reset.invalid_token")
    end

    def password_params
      params.require(:admin_user).permit(:password, :password_confirmation)
    end
  end
end
