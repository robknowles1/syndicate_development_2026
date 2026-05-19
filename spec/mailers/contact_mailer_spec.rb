require "rails_helper"

RSpec.describe ContactMailer, type: :mailer do
  describe "#contact_email" do
    let(:mail) do
      ContactMailer.contact_email(
        name: "Jane Rider",
        email: "jane@example.com",
        subject: "Engine build question",
        message: "I would like to enquire about a full engine build."
      )
    end

    it "uses the locale key value for the subject prefix" do
      expect(mail.subject).to start_with(I18n.t("mailer.contact_email.subject_prefix"))
    end

    it "includes the caller-supplied subject after the prefix" do
      expect(mail.subject).to include("Engine build question")
    end

    it "is addressed to the shop email" do
      expect(mail.to).to include("robknowles105@gmail.com")
    end

    it "sets reply-to to the sender's email" do
      expect(mail.reply_to).to include("jane@example.com")
    end
  end
end
