require "rails_helper"

RSpec.describe "Admin::Accounts", type: :request do
  def sign_in(admin)
    post admin_login_path, params: { email: admin.email, password: "securepassword123" }
  end

  describe "authorization" do
    it "requires a signed-in admin" do
      # Act
      get edit_admin_account_path

      # Assert
      expect(response).to redirect_to(admin_login_path)
    end
  end

  describe "PATCH /admin/account" do
    it "changes the password when the current one is given" do
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

      # Assert
      expect(response).to redirect_to(admin_root_path)
      expect(admin.reload.authenticate("a-completely-new-one")).to be_truthy
    end

    it "keeps the admin signed in afterwards" do
      # Arrange — the session is reset on change; the admin must not be logged out
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

    it "refuses when the current password is wrong" do
      # Arrange
      admin = create(:admin_user)
      sign_in(admin)

      # Act
      patch admin_account_path, params: {
        admin_user: {
          current_password: "not-the-right-one",
          password: "a-completely-new-one",
          password_confirmation: "a-completely-new-one"
        }
      }

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(admin.reload.authenticate("a-completely-new-one")).to be_falsey
    end

    it "refuses when the confirmation does not match" do
      # Arrange
      admin = create(:admin_user)
      sign_in(admin)

      # Act
      patch admin_account_path, params: {
        admin_user: {
          current_password: "securepassword123",
          password: "a-completely-new-one",
          password_confirmation: "something-different"
        }
      }

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(admin.reload.authenticate("securepassword123")).to be_truthy
    end

    it "rejects a blank password instead of reporting success" do
      # Arrange — has_secure_password ignores a blank assignment, so the old digest
      # survives while the flash claims the password was changed
      admin = create(:admin_user)
      sign_in(admin)

      # Act
      patch admin_account_path, params: {
        admin_user: {
          current_password: "securepassword123",
          password: "",
          password_confirmation: ""
        }
      }

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(flash[:notice]).to be_nil
      expect(admin.reload.authenticate("securepassword123")).to be_truthy
    end

    it "rejects a payload with no password key instead of reporting success" do
      # Arrange — with the key absent, password= is never called at all, so nothing records
      # a blank attempt and the update succeeds while the flash claims a change that never
      # reached the digest
      admin = create(:admin_user)
      sign_in(admin)

      # Act
      patch admin_account_path, params: {
        admin_user: { current_password: "securepassword123", unrelated: "x" }
      }

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(flash[:notice]).to be_nil
      expect(admin.reload.authenticate("securepassword123")).to be_truthy
    end

    it "invalidates any outstanding password reset link" do
      # Arrange
      admin = create(:admin_user)
      token = admin.generate_token_for(:password_reset)
      sign_in(admin)

      # Act
      patch admin_account_path, params: {
        admin_user: {
          current_password: "securepassword123",
          password: "a-completely-new-one",
          password_confirmation: "a-completely-new-one"
        }
      }

      # Assert
      expect(AdminUser.find_by_token_for(:password_reset, token)).to be_nil
    end
  end
end
