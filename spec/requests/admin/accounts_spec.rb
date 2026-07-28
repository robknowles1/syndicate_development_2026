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
