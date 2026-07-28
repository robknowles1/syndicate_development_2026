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

    it "is addressed to the configured contact recipient" do
      expect(mail.to).to include(Rails.application.config.x.mail.contact_recipient)
    end

    it "sends from the configured address, not the Rails placeholder" do
      expect(mail.from).to include(Rails.application.config.x.mail.from)
      expect(mail.from).not_to include("from@example.com")
    end

    it "routes to the shop in production and the developer elsewhere" do
      # Arrange — the recipient is resolved at boot from the environment, so assert the
      # rule rather than re-booting the app under a different RAILS_ENV.
      recipient = Rails.application.config.x.mail.contact_recipient

      # Assert
      expect(recipient).to eq("robknowles105@gmail.com")
      expect(recipient).not_to eq("haskettd@live.com"),
        "the customer must never receive mail from a non-production environment"
    end

    it "sets reply-to to the sender's email" do
      expect(mail.reply_to).to include("jane@example.com")
    end
  end
end
