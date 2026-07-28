module Admin
  class BaseController < ApplicationController
    layout "admin"

    before_action :require_admin

    helper_method :current_admin

    private

    def require_admin
      redirect_to admin_login_path unless current_admin
    end

    # Resolving the row rather than trusting the id is what makes removing an admin take
    # effect: their cookie still carries a valid id, and the row is the only thing that
    # says whether they are still an admin.
    def current_admin
      return @current_admin if defined?(@current_admin)

      @current_admin = authenticated_admin_from_session
    end

    def authenticated_admin_from_session
      admin_user = AdminUser.find_by(id: session[:admin_user_id])
      return nil unless admin_user&.active?

      # Two independent bindings, because each catches what the other misses. The salt
      # covers a password changed outside the app, where no controller runs to rotate
      # anything; the session token is the only thing logout can revoke, since the cookie
      # store keeps nothing server-side to delete.
      return nil unless session_binding_valid?(session[:auth_digest], admin_user.password_salt&.last(10))
      return nil unless session_binding_valid?(session[:session_token], admin_user.session_token)

      admin_user
    end

    def session_binding_valid?(presented, expected)
      return false unless presented.present? && expected.present?

      ActiveSupport::SecurityUtils.secure_compare(presented, expected)
    end

    # The single place a session becomes authenticated. Refuses an account that cannot
    # sign in, so no flow can hand out a session the login form would have denied.
    def sign_in(admin_user)
      return false unless admin_user.active?

      # Discard the pre-login session before granting privileges. Carrying it over lets an
      # attacker who fixed the session id beforehand ride the authenticated session after.
      reset_session
      session[:admin_user_id] = admin_user.id
      session[:auth_digest] = admin_user.password_salt.last(10)
      session[:session_token] = admin_user.rotate_session_token!
      @current_admin = admin_user
      true
    end

    # sign_in refuses an account that could not log in. Every caller has just set a
    # password, so the change stands either way — send them to the login form rather than
    # to a dashboard that would bounce them straight back to it.
    def sign_in_and_redirect(admin_user, notice:)
      return redirect_to admin_root_path, notice: notice if sign_in(admin_user)

      redirect_to admin_login_path, notice: notice
    end
  end
end
