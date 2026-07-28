require "rails_helper"

RSpec.describe AdminMailer, type: :mailer do
  describe "#invitation" do
    it "addresses the invitee and carries a working invitation link" do
      # Arrange
      admin = create(:admin_user, :pending_invitation, email: "invitee@example.com")

      # Act
      mail = described_class.invitation(admin)

      # Assert
      expect(mail.to).to eq([ "invitee@example.com" ])
      expect(mail.subject).to eq(I18n.t("admin_mailer.invitation.subject"))

      # decoded, not encoded: quoted-printable soft-wraps long tokens across lines
      token = mail.text_part.decoded[%r{/admin/invitation/([^/\s"]+)/edit}, 1]
      expect(token).to be_present
      expect(AdminUser.find_by_token_for(:invitation, token)).to eq(admin)
    end

    it "builds absolute links from default_url_options" do
      # Arrange
      admin = create(:admin_user, :pending_invitation)

      # Act
      mail = described_class.invitation(admin)

      # Assert — a relative link is unusable in an email client. The real hosts are
      # asserted per environment; here it only matters that the URL is absolute.
      expect(mail.text_part.decoded).to match(%r{https?://[^/]+/admin/invitation/})
    end
  end

  describe "#password_reset" do
    it "addresses the admin and carries a working reset link" do
      # Arrange
      admin = create(:admin_user, email: "doug@example.com")

      # Act
      mail = described_class.password_reset(admin)

      # Assert
      expect(mail.to).to eq([ "doug@example.com" ])
      expect(mail.subject).to eq(I18n.t("admin_mailer.password_reset.subject"))

      token = mail.text_part.decoded[%r{/admin/password_reset/([^/\s"]+)/edit}, 1]
      expect(token).to be_present
      expect(AdminUser.find_by_token_for(:password_reset, token)).to eq(admin)
    end

    it "sends from the configured address" do
      # Arrange
      admin = create(:admin_user)

      # Act
      mail = described_class.password_reset(admin)

      # Assert
      expect(mail.from).to include(Rails.application.config.x.mail.from)
    end
  end
end
