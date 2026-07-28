require "rails_helper"

RSpec.describe ContactMailer, type: :mailer do
  def enquiry_email
    described_class.contact_email(
      name: "Jane Rider",
      email: "jane@example.com",
      subject: "Engine build question",
      message: "I would like to enquire about a full engine build."
    )
  end

  describe "#contact_email" do
    it "uses the locale key value for the subject prefix" do
      expect(enquiry_email.subject).to start_with(I18n.t("mailer.contact_email.subject_prefix"))
    end

    it "includes the caller-supplied subject after the prefix" do
      expect(enquiry_email.subject).to include("Engine build question")
    end

    it "addresses the developer, never the shop, outside production" do
      expect(enquiry_email.to).to eq([ "robknowles105@gmail.com" ])
    end

    it "sends from the verified no-reply address, not the Rails placeholder" do
      expect(enquiry_email.from).to eq([ "noreply@mail.syndicate-development.com" ])
    end

    it "sets reply-to to the sender's email" do
      expect(enquiry_email.reply_to).to eq([ "jane@example.com" ])
    end
  end
end
