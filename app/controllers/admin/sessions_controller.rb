module Admin
  class SessionsController < BaseController
    skip_before_action :require_admin

    # Keyed on the address as well as the IP, because on the IP alone anyone can lock a
    # known admin out by failing ten logins from a shared address.
    #
    # The residual this leaves: N addresses each get their own allowance against one
    # account, so distributed guessing is capped per source rather than per account. An
    # address-only limit would close that and hand the same attacker a lockout instead —
    # worse, because the reset link they would fall back on issues a password they still
    # could not use. Against a 12-character minimum at bcrypt cost, what the per-IP limit
    # below permits is not a number of guesses that gets anyone anywhere.
    rate_limit to: 10, within: 3.minutes, only: :create, name: "login_per_account",
      by: -> { [ request.remote_ip, params[:email].to_s.strip.downcase ].join("|") },
      with: -> { redirect_to admin_login_path, alert: I18n.t("admin.login.too_many_attempts") }

    rate_limit to: 50, within: 3.minutes, only: :create, name: "login_per_ip",
      with: -> { redirect_to admin_login_path, alert: I18n.t("admin.login.too_many_attempts") }

    def new
    end

    def create
      admin = AdminUser.authenticate_by_email(params[:email], params[:password])

      if admin && sign_in(admin)
        redirect_to admin_root_path
      else
        # One message for every failure, and authenticate_by_email spends the same bcrypt
        # work whether or not the address exists, so neither the body nor the response
        # time distinguishes a wrong password from an address with no account.
        flash.now[:alert] = I18n.t("admin.login.invalid_credentials")
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      # reset_session only clears the cookie this client happens to be holding. Clearing the
      # stored token is what makes logout revoke a cookie that was copied elsewhere.
      current_admin&.clear_session_token!
      reset_session
      redirect_to admin_login_path
    end
  end
end
