module Admin
  class SessionsController < BaseController
    skip_before_action :require_admin

    # Keyed on the address as well as the IP, so exhausting the allowance from one source
    # denies that source rather than every admin behind it. This is the tightest of the
    # three and the one a mistyped password meets first; it clears in three minutes.
    rate_limit to: 10, within: 3.minutes, only: :create, name: "login_per_account",
      by: -> { [ request.remote_ip, params[:email].to_s.strip.downcase ].join("|") },
      with: -> { redirect_to admin_login_path, alert: I18n.t("admin.login.too_many_attempts") }

    # The bound that holds when remote_ip is worthless. Both limits keyed on it are reset
    # by a header the caller writes, and a composite of the two is reset by the same one
    # header, so the account needs an allowance that nothing in the request can vary
    # except the choice of which account to attack.
    #
    # 20 in 15 minutes is far past retyping a password and caps a distributed attack at 80
    # guesses an hour against a 12-character minimum. It is also a lockout anyone knowing
    # the address can hold open, which is why the window is short and why the reset link —
    # which signs the admin in without passing through here — is the way out.
    rate_limit to: 20, within: 15.minutes, only: :create, name: "login_per_email",
      by: -> { params[:email].to_s.strip.downcase },
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
