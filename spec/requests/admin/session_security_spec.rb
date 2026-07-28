require "rails_helper"

RSpec.describe "Admin session security", type: :request do
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

  describe "generic failure messages" do
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
