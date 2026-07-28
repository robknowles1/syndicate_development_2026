require "rails_helper"

RSpec.describe "Admin session security", type: :request do
  def sign_in(admin, password: "securepassword123")
    post admin_login_path, params: { email: admin.email, password: password }
  end

  # A second client holding its own authenticated cookie. Standing in for a cookie that
  # has been captured, it is the only way to observe revocation: reset_session clears the
  # calling client alone, so a single-session spec cannot tell revocation from a no-op.
  def separate_signed_in_client(admin, password: "securepassword123")
    client = ActionDispatch::Integration::Session.new(Rails.application)
    client.host! "www.example.com"
    client.post "/admin/login", params: { email: admin.email, password: password }
    client
  end

  # A second client holding a copy of this one's session cookie, standing in for a cookie
  # that has been captured rather than one obtained by logging in. Logging in again would
  # rotate the session token, which is the very thing under test here.
  def client_sharing_this_session
    session_key = Rails.application.config.session_options[:key]
    client = ActionDispatch::Integration::Session.new(Rails.application)
    client.host! "www.example.com"
    client.cookies[session_key] = cookies[session_key]
    client
  end

  describe "revoking a removed admin" do
    it "stops honouring the cookie of an admin who has been deleted" do
      # Arrange
      owner = create(:admin_user, email: "owner@example.com")
      removed = create(:admin_user, email: "removed@example.com")
      removed_client = separate_signed_in_client(removed)
      sign_in(owner)

      # Act
      delete admin_user_path(removed)
      removed_client.get "/admin"

      # Assert
      expect(removed_client.response.redirect_url).to eq(admin_login_url)
    end

    it "stops a deleted admin reaching the admin user list" do
      # Arrange
      owner = create(:admin_user, email: "owner@example.com")
      removed = create(:admin_user, email: "removed@example.com")
      removed_client = separate_signed_in_client(removed)
      sign_in(owner)

      # Act
      delete admin_user_path(removed)
      removed_client.get "/admin/users"

      # Assert
      expect(removed_client.response.redirect_url).to eq(admin_login_url)
    end

    it "stops a deleted admin creating a replacement account" do
      # Arrange
      owner = create(:admin_user, email: "owner@example.com")
      removed = create(:admin_user, email: "removed@example.com")
      removed_client = separate_signed_in_client(removed)
      sign_in(owner)

      # Act
      delete admin_user_path(removed)
      removed_client.post "/admin/users", params: { admin_user: { email: "backdoor@example.com" } }

      # Assert
      expect(AdminUser.find_by(email: "backdoor@example.com")).to be_nil
    end

    it "stops a deleted admin removing the remaining legitimate admin" do
      # Arrange — the self-guard compares against current_admin, which is nil once the
      # acting admin's own row is gone, so it would otherwise permit this
      owner = create(:admin_user, email: "owner@example.com")
      removed = create(:admin_user, email: "removed@example.com")
      removed_client = separate_signed_in_client(removed)
      sign_in(owner)

      # Act
      delete admin_user_path(removed)
      removed_client.delete "/admin/users/#{owner.id}"

      # Assert
      expect(AdminUser.exists?(owner.id)).to be(true)
    end
  end

  describe "revoking a session at logout" do
    it "stops honouring a copy of the cookie once the admin has logged out" do
      # Arrange — reset_session discards only the cookie held by the client that logged
      # out, so a copy is the only way to tell revocation from a no-op
      admin = create(:admin_user)
      sign_in(admin)
      captured_client = client_sharing_this_session

      # Act
      delete admin_logout_path
      captured_client.get "/admin"

      # Assert
      expect(captured_client.response.redirect_url).to eq(admin_login_url)
    end

    it "leaves another admin signed in when one of them logs out" do
      # Arrange — revocation is per account, not a global flush
      colleague = create(:admin_user, email: "colleague@example.com")
      colleague_client = separate_signed_in_client(colleague)
      sign_in(create(:admin_user, email: "doug@example.com"))

      # Act
      delete admin_logout_path
      colleague_client.get "/admin"

      # Assert
      expect(colleague_client.response).to have_http_status(:ok)
    end
  end

  describe "session expiry" do
    it "stops honouring a session cookie once it has outlived its expiry" do
      # Arrange — a password change and a logout are the only other things that end a
      # session, and neither is something an attacker holding a copied cookie will do
      admin = create(:admin_user)
      sign_in(admin)
      session_lifetime = Rails.application.config.session_options.fetch(:expire_after)

      # Act
      travel(session_lifetime + 1.hour) do
        get admin_root_path
      end

      # Assert
      expect(response).to redirect_to(admin_login_path)
    end
  end

  describe "concurrent sessions" do
    it "revokes an earlier session when the same admin signs in again" do
      # Arrange
      admin = create(:admin_user)
      sign_in(admin)
      earlier_client = client_sharing_this_session

      # Act
      separate_signed_in_client(admin)
      earlier_client.get "/admin"

      # Assert
      expect(earlier_client.response.redirect_url).to eq(admin_login_url)
    end
  end

  describe "revoking sessions on a password change" do
    it "stops honouring a cookie after the password is changed outside the app" do
      # Arrange — a console or rake-task change rotates the password salt but runs no
      # controller, so nothing rotates the session token and the salt binding is the only
      # thing left to catch it
      admin = create(:admin_user)
      sign_in(admin)

      # Act
      admin.update!(password: "a-completely-new-one", password_confirmation: "a-completely-new-one")
      get admin_root_path

      # Assert
      expect(response).to redirect_to(admin_login_path)
    end

    it "logs out other sessions when the password is set through a reset link" do
      # Arrange
      admin = create(:admin_user)
      other_client = separate_signed_in_client(admin)

      # Act
      get admin_claim_password_reset_path(admin.generate_token_for(:password_reset))
      follow_redirect!
      patch admin_password_reset_update_path, params: {
        admin_user: { password: "a-brand-new-password", password_confirmation: "a-brand-new-password" }
      }
      other_client.get "/admin"

      # Assert
      expect(other_client.response.redirect_url).to eq(admin_login_url)
    end

    it "keeps the session that made the change signed in" do
      # Arrange
      admin = create(:admin_user)
      sign_in(admin)

      # Act
      patch admin_account_path, params: {
        admin_user: {
          current_password: "securepassword123",
          password: "a-completely-new-one",
          password_confirmation: "a-completely-new-one"
        }
      }
      get admin_root_path

      # Assert
      expect(response).to have_http_status(:ok)
    end
  end

  describe "session fixation" do
    it "issues a new session id at login rather than reusing the pre-login one" do
      # Arrange — establish a real pre-login session. A bare GET of the login page writes
      # nothing, so drive a request that sets a flash and therefore persists a session.
      post admin_password_reset_path, params: { email: "nobody@example.com" }
      before_login = session.id.to_s
      expect(before_login).to be_present

      admin = create(:admin_user)

      # Act
      post admin_login_path, params: { email: admin.email, password: "securepassword123" }

      # Assert — carrying the id over is what lets a fixed session become authenticated
      expect(session.id.to_s).to be_present
      expect(session.id.to_s).not_to eq(before_login)
    end
  end

  describe "case-insensitive login" do
    it "signs in when the email case differs from what was stored" do
      # Arrange
      create(:admin_user, email: "doug@example.com")

      # Act
      post admin_login_path, params: { email: "Doug@Example.COM", password: "securepassword123" }

      # Assert
      expect(response).to redirect_to(admin_root_path)
    end

    it "signs in when the typed email has surrounding whitespace" do
      # Arrange
      create(:admin_user, email: "doug@example.com")

      # Act
      post admin_login_path, params: { email: "  doug@example.com  ", password: "securepassword123" }

      # Assert
      expect(response).to redirect_to(admin_root_path)
    end
  end

  describe "login rate limiting" do
    it "throttles repeated failed attempts" do
      # Arrange
      create(:admin_user, email: "doug@example.com")

      # Act — the limit is 10 within 3 minutes
      11.times do
        post admin_login_path, params: { email: "doug@example.com", password: "wrong-password" }
      end

      # Assert
      expect(response).to redirect_to(admin_login_path)
      expect(flash[:alert]).to eq(I18n.t("admin.login.too_many_attempts"))
    end

    it "does not let attempts against one address lock out another" do
      # Arrange — keyed on the IP alone, exhausting the limit for any address would deny
      # every admin behind that IP, which is a denial of service anyone can trigger
      create(:admin_user, email: "doug@example.com")
      create(:admin_user, email: "colleague@example.com")

      # Act
      11.times do
        post admin_login_path, params: { email: "doug@example.com", password: "wrong-password" }
      end
      post admin_login_path, params: { email: "colleague@example.com", password: "securepassword123" }

      # Assert
      expect(response).to redirect_to(admin_root_path)
    end

    it "counts attempts against one address regardless of the case typed" do
      # Arrange — the address is normalized before lookup, so the limit must normalize too
      create(:admin_user, email: "doug@example.com")

      # Act
      6.times { post admin_login_path, params: { email: "doug@example.com", password: "wrong-password" } }
      5.times { post admin_login_path, params: { email: "DOUG@EXAMPLE.COM", password: "wrong-password" } }

      # Assert
      expect(flash[:alert]).to eq(I18n.t("admin.login.too_many_attempts"))
    end

    it "throttles before an attacker can work through many guesses" do
      # Arrange
      create(:admin_user, email: "doug@example.com")

      # Act
      attempts = 0
      30.times do
        post admin_login_path, params: { email: "doug@example.com", password: "guess-#{attempts}" }
        attempts += 1
        break if flash[:alert] == I18n.t("admin.login.too_many_attempts")
      end

      # Assert
      expect(attempts).to be <= 11
    end
  end

  describe "indistinguishable failures" do
    it "spends the same bcrypt work on an unknown address as on a known one" do
      # Arrange — skipping bcrypt for unknown addresses makes them answer in a couple of
      # milliseconds against a couple of hundred, which reads back as "no account here".
      # Spied on the hashing rather than on BCrypt::Password.new, which only parses a
      # digest string and so costs nothing: dropping the comparison would still satisfy it.
      create(:admin_user, email: "doug@example.com")
      allow(BCrypt::Engine).to receive(:hash_secret).and_call_original

      # Act
      post admin_login_path, params: { email: "nobody@example.com", password: "wrong-password" }

      # Assert — the submitted password, not the throwaway secret behind the dummy digest
      expect(BCrypt::Engine).to have_received(:hash_secret).with("wrong-password", anything)
    end

    it "gives the same message for an unknown address and a wrong password" do
      # Arrange
      create(:admin_user, email: "doug@example.com")

      # Act
      post admin_login_path, params: { email: "doug@example.com", password: "wrong-password" }
      wrong_password_body = response.body

      post admin_login_path, params: { email: "nobody@example.com", password: "wrong-password" }
      unknown_email_body = response.body

      # Assert — differing responses would let an attacker enumerate valid addresses
      expect(wrong_password_body).to include(I18n.t("admin.login.invalid_credentials"))
      expect(unknown_email_body).to include(I18n.t("admin.login.invalid_credentials"))
    end
  end
end
