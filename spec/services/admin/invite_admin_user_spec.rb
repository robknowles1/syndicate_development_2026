require "rails_helper"

RSpec.describe Admin::InviteAdminUser do
  describe "#call" do
    it "saves the invitee and reports the invitation as sent" do
      # Arrange
      service = described_class.new("newperson@example.com")

      # Act
      result = service.call

      # Assert
      expect(result.status).to eq(:invited)
      expect(result.admin_user).to be_persisted
      expect(ActionMailer::Base.deliveries.last.to).to eq([ "newperson@example.com" ])
    end

    context "when the invitation email cannot be delivered" do
      it "removes the orphan row and reports the failure" do
        # Arrange — the saved row occupies the address, and uniqueness then refuses a
        # second invite, so an undelivered invitation would block that person permanently
        undeliverable = double(:mail)
        allow(undeliverable).to receive(:deliver_now).and_raise(Net::SMTPServerBusy, "mailbox unavailable")
        allow(AdminMailer).to receive(:invitation).and_return(undeliverable)

        # Act
        result = described_class.new("newperson@example.com").call

        # Assert
        expect(result.status).to eq(:delivery_failed)
        expect(AdminUser.find_by(email: "newperson@example.com")).to be_nil
      end

      it "reports the failure rather than raising when the orphan row cannot be removed" do
        # Arrange — an exception escaping the rescue 500s the invite form and leaves the
        # row behind anyway, which is the outcome the rescue exists to prevent
        invitee = AdminUser.new(email: "newperson@example.com", invited_at: Time.current)
        allow(invitee).to receive(:destroy).and_raise(ActiveRecord::InvalidForeignKey, "still referenced")
        allow(AdminUser).to receive(:new).and_return(invitee)
        undeliverable = double(:mail)
        allow(undeliverable).to receive(:deliver_now).and_raise(Net::SMTPServerBusy, "mailbox unavailable")
        allow(AdminMailer).to receive(:invitation).and_return(undeliverable)

        # Act
        result = described_class.new("newperson@example.com").call

        # Assert
        expect(result.status).to eq(:delivery_failed)
      end
    end
  end
end
