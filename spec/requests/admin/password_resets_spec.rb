require "rails_helper"

RSpec.describe "Admin::PasswordResets", type: :request do
  before { ActionMailer::Base.deliveries.clear }

  describe "POST /admin/password_reset" do
    it "emails a reset link to a known address" do
      # Arrange
      admin = create(:admin_user, email: "known@example.com")

      # Act
      post admin_password_reset_path, params: { email: admin.email }

      # Assert
      expect(ActionMailer::Base.deliveries.size).to eq(1)
      expect(ActionMailer::Base.deliveries.last.to).to eq([ admin.email ])
    end

    it "gives an identical response for an unknown address, without sending mail" do
      # Arrange
      create(:admin_user, email: "known@example.com")

      # Act
      post admin_password_reset_path, params: { email: "stranger@example.com" }

      # Assert — the response must not reveal whether the account exists
      expect(response).to redirect_to(admin_login_path)
      expect(flash[:notice]).to eq(I18n.t("admin.password_reset.sent"))
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "finds the account regardless of the case typed" do
      # Arrange
      admin = create(:admin_user, email: "known@example.com")

      # Act
      post admin_password_reset_path, params: { email: "KNOWN@Example.COM" }

      # Assert
      expect(ActionMailer::Base.deliveries.size).to eq(1)
      expect(ActionMailer::Base.deliveries.last.to).to eq([ admin.email ])
    end

    it "does not send to an admin with an unaccepted invitation" do
      # Arrange
      admin = create(:admin_user, :pending_invitation, email: "pending@example.com")

      # Act
      post admin_password_reset_path, params: { email: admin.email }

      # Assert
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  describe "PATCH /admin/password_reset/:token" do
    it "updates the password and signs the admin in" do
      # Arrange
      admin = create(:admin_user)
      token = admin.generate_token_for(:password_reset)

      # Act
      patch admin_password_reset_update_path(token), params: {
        admin_user: { password: "a-brand-new-password", password_confirmation: "a-brand-new-password" }
      }

      # Assert
      expect(response).to redirect_to(admin_root_path)
      expect(admin.reload.authenticate("a-brand-new-password")).to be_truthy

      get admin_root_path
      expect(response).to have_http_status(:ok)
    end

    it "refuses a token that has already been used" do
      # Arrange — the first reset rotates the salt the token derives from
      admin = create(:admin_user)
      token = admin.generate_token_for(:password_reset)
      patch admin_password_reset_update_path(token), params: {
        admin_user: { password: "a-brand-new-password", password_confirmation: "a-brand-new-password" }
      }

      # Act
      patch admin_password_reset_update_path(token), params: {
        admin_user: { password: "yet-another-password", password_confirmation: "yet-another-password" }
      }

      # Assert
      expect(response).to redirect_to(new_admin_password_reset_path)
      expect(admin.reload.authenticate("yet-another-password")).to be_falsey
    end

    it "refuses a token older than its 2 hour lifetime" do
      # Arrange
      admin = create(:admin_user)
      token = admin.generate_token_for(:password_reset)

      # Act
      travel 3.hours do
        patch admin_password_reset_update_path(token), params: {
          admin_user: { password: "a-brand-new-password", password_confirmation: "a-brand-new-password" }
        }
      end

      # Assert
      expect(response).to redirect_to(new_admin_password_reset_path)
      expect(admin.reload.authenticate("a-brand-new-password")).to be_falsey
    end

    it "re-renders when the password is too short" do
      # Arrange
      admin = create(:admin_user)
      token = admin.generate_token_for(:password_reset)

      # Act
      patch admin_password_reset_update_path(token), params: {
        admin_user: { password: "short", password_confirmation: "short" }
      }

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "rate limiting" do
    it "throttles repeated reset requests" do
      # Arrange
      create(:admin_user, email: "known@example.com")

      # Act — the limit is 5 within 15 minutes
      6.times { post admin_password_reset_path, params: { email: "known@example.com" } }

      # Assert
      expect(response).to redirect_to(new_admin_password_reset_path)
      expect(flash[:alert]).to eq(I18n.t("admin.password_reset.too_many_requests"))
    end
  end
end
