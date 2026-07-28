require "rails_helper"

RSpec.describe "Admin::Invitations", type: :request do
  def invite!(email: "invitee@example.com")
    admin = AdminUser.new(email: email, invited_at: Time.current)
    admin.password = SecureRandom.base58(32)
    admin.save!
    admin
  end

  describe "GET /admin/invitation/:token/edit" do
    it "renders the password form for a pending invitation" do
      # Arrange
      admin = invite!

      # Act
      get admin_edit_invitation_path(admin.generate_token_for(:invitation))

      # Assert
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(admin.email)
    end

    it "rejects a garbage token" do
      # Act
      get admin_edit_invitation_path("not-a-real-token")

      # Assert
      expect(response).to redirect_to(admin_login_path)
      expect(flash[:alert]).to eq(I18n.t("admin.invitation.invalid_token"))
    end

    it "rejects a token for an already-accepted invitation" do
      # Arrange — acceptance rotates the password salt the token derives from
      admin = invite!
      token = admin.generate_token_for(:invitation)
      admin.accept_invitation(password: "brandnewpassword", password_confirmation: "brandnewpassword")

      # Act
      get admin_edit_invitation_path(token)

      # Assert
      expect(response).to redirect_to(admin_login_path)
    end

    it "rejects an expired token" do
      # Arrange
      admin = invite!
      token = admin.generate_token_for(:invitation)

      # Act
      travel 8.days do
        get admin_edit_invitation_path(token)
      end

      # Assert
      expect(response).to redirect_to(admin_login_path)
    end
  end

  describe "PATCH /admin/invitation/:token" do
    it "sets the password, marks the invitation accepted, and signs the admin in" do
      # Arrange
      admin = invite!
      token = admin.generate_token_for(:invitation)

      # Act
      patch admin_invitation_update_path(token), params: {
        admin_user: { password: "brandnewpassword", password_confirmation: "brandnewpassword" }
      }

      # Assert
      expect(response).to redirect_to(admin_root_path)
      admin.reload
      expect(admin.invitation_accepted_at).to be_present
      expect(admin.invitation_pending?).to be(false)
      expect(admin.authenticate("brandnewpassword")).to be_truthy

      # The session really is authenticated, not just redirected
      get admin_root_path
      expect(response).to have_http_status(:ok)
    end

    it "re-renders when the confirmation does not match" do
      # Arrange
      admin = invite!
      token = admin.generate_token_for(:invitation)

      # Act
      patch admin_invitation_update_path(token), params: {
        admin_user: { password: "brandnewpassword", password_confirmation: "different-entirely" }
      }

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(admin.reload.invitation_pending?).to be(true)
    end

    it "re-renders when the password is below the minimum length" do
      # Arrange
      admin = invite!
      token = admin.generate_token_for(:invitation)

      # Act
      patch admin_invitation_update_path(token), params: {
        admin_user: { password: "short", password_confirmation: "short" }
      }

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(admin.reload.invitation_pending?).to be(true)
    end
  end

  describe "an invited admin who has not accepted" do
    it "cannot sign in with the placeholder password even if it were guessed" do
      # Arrange
      admin = AdminUser.new(email: "pending@example.com", invited_at: Time.current)
      placeholder = SecureRandom.base58(32)
      admin.password = placeholder
      admin.save!

      # Act
      post admin_login_path, params: { email: admin.email, password: placeholder }

      # Assert — credentials are correct, but the account is not active
      expect(response).to have_http_status(:unprocessable_entity)
      expect(flash.now[:alert]).to eq(I18n.t("admin.login.invalid_credentials"))
    end
  end
end
