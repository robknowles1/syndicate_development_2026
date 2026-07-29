require "rails_helper"

RSpec.describe "Admin::Users", type: :request do
  def sign_in(admin)
    post admin_login_path, params: { email: admin.email, password: "securepassword123" }
  end

  before { ActionMailer::Base.deliveries.clear }

  describe "authorization" do
    it "requires a signed-in admin for every action" do
      # Act / Assert
      get admin_users_path
      expect(response).to redirect_to(admin_login_path)

      get new_admin_user_path
      expect(response).to redirect_to(admin_login_path)

      post admin_users_path, params: { admin_user: { email: "sneaky@example.com" } }
      expect(response).to redirect_to(admin_login_path)
      expect(AdminUser.find_by(email: "sneaky@example.com")).to be_nil
    end
  end

  describe "POST /admin/users" do
    it "creates a pending admin and emails an invitation" do
      # Arrange
      sign_in(create(:admin_user))

      # Act
      post admin_users_path, params: { admin_user: { email: "newperson@example.com" } }

      # Assert
      invited = AdminUser.find_by(email: "newperson@example.com")
      expect(invited).to be_present
      expect(invited.invitation_pending?).to be(true)
      expect(ActionMailer::Base.deliveries.last.to).to eq([ "newperson@example.com" ])
      expect(response).to redirect_to(admin_users_path)
    end

    it "normalizes the invited address" do
      # Arrange
      sign_in(create(:admin_user))

      # Act
      post admin_users_path, params: { admin_user: { email: "  MixedCase@Example.COM  " } }

      # Assert
      expect(AdminUser.find_by(email: "mixedcase@example.com")).to be_present
    end

    it "rejects a duplicate address without sending mail" do
      # Arrange
      admin = create(:admin_user)
      sign_in(admin)

      # Act
      post admin_users_path, params: { admin_user: { email: admin.email } }

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "rejects a malformed address" do
      # Arrange
      sign_in(create(:admin_user))

      # Act
      post admin_users_path, params: { admin_user: { email: "not-an-email" } }

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "leaves no pending admin behind when the invitation email cannot be delivered" do
      # Arrange — a saved row occupies the address, and uniqueness then refuses a retry,
      # so a failed delivery would permanently block inviting that person
      sign_in(create(:admin_user))
      mailer = double(:mail)
      allow(mailer).to receive(:deliver_now).and_raise(Net::SMTPServerBusy, "mailbox unavailable")
      allow(AdminMailer).to receive(:invitation).and_return(mailer)

      # Act
      post admin_users_path, params: { admin_user: { email: "newperson@example.com" } }

      # Assert
      expect(AdminUser.find_by(email: "newperson@example.com")).to be_nil
      expect(flash[:alert]).to eq(I18n.t("admin.users.invitation_delivery_failed"))
    end

    it "lets the same address be invited again after a delivery failure" do
      # Arrange
      sign_in(create(:admin_user))
      failing_mailer = double(:mail)
      allow(failing_mailer).to receive(:deliver_now).and_raise(Net::SMTPServerBusy, "mailbox unavailable")
      allow(AdminMailer).to receive(:invitation).and_return(failing_mailer)
      post admin_users_path, params: { admin_user: { email: "newperson@example.com" } }
      allow(AdminMailer).to receive(:invitation).and_call_original

      # Act
      post admin_users_path, params: { admin_user: { email: "newperson@example.com" } }

      # Assert
      expect(AdminUser.find_by(email: "newperson@example.com")).to be_present
      expect(response).to redirect_to(admin_users_path)
    end

    it "does not let the invited address be set with a chosen password" do
      # Arrange — password must come from the emailed link, never the invite form
      sign_in(create(:admin_user))

      # Act
      post admin_users_path, params: {
        admin_user: { email: "newperson@example.com", password: "attacker-chosen-pw" }
      }

      # Assert
      invited = AdminUser.find_by(email: "newperson@example.com")
      expect(invited.authenticate("attacker-chosen-pw")).to be_falsey
    end
  end

  describe "DELETE /admin/users/:id" do
    it "removes another admin" do
      # Arrange
      admin = create(:admin_user, email: "me@example.com")
      other = create(:admin_user, email: "other@example.com")
      sign_in(admin)

      # Act
      delete admin_user_path(other)

      # Assert
      expect(AdminUser.exists?(other.id)).to be(false)
      expect(response).to redirect_to(admin_users_path)
    end

    it "refuses to remove your own account" do
      # Arrange
      admin = create(:admin_user, email: "me@example.com")
      create(:admin_user, email: "other@example.com")
      sign_in(admin)

      # Act
      delete admin_user_path(admin)

      # Assert
      expect(AdminUser.exists?(admin.id)).to be(true)
      expect(flash[:alert]).to eq(I18n.t("admin.users.cannot_remove_self"))
    end

    it "leaves the only admin in place, because removing them would be removing yourself" do
      # Arrange
      admin = create(:admin_user, email: "onlyone@example.com")
      sign_in(admin)

      # Act
      delete admin_user_path(admin)

      # Assert
      expect(AdminUser.count).to eq(1)
      expect(flash[:alert]).to eq(I18n.t("admin.users.cannot_remove_self"))
    end
  end
end
