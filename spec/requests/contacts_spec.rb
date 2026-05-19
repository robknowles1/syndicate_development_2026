require "rails_helper"

RSpec.describe "Contacts", type: :request do
  describe "POST /contact" do
    let(:valid_params) do
      {
        name: "Jane Rider",
        email: "jane@example.com",
        subject: "Engine build question",
        message: "I would like to enquire about a full engine build."
      }
    end

    context "with valid params" do
      it "redirects to /about" do
        ActionMailer::Base.delivery_method = :test
        post contact_path, params: valid_params
        expect(response).to redirect_to(about_path)
      end

      it "sets a flash notice matching the locale value" do
        ActionMailer::Base.delivery_method = :test
        post contact_path, params: valid_params
        expect(flash[:notice]).to eq(I18n.t("contact.notices.message_sent"))
      end

      it "delivers an email" do
        ActionMailer::Base.delivery_method = :test
        ActionMailer::Base.deliveries.clear
        post contact_path, params: valid_params
        expect(ActionMailer::Base.deliveries.count).to eq(1)
      end

      it "sends email to the shop address" do
        ActionMailer::Base.delivery_method = :test
        ActionMailer::Base.deliveries.clear
        post contact_path, params: valid_params
        mail = ActionMailer::Base.deliveries.last
        expect(mail.to).to include("robknowles105@gmail.com")
      end
    end

    context "when name is missing" do
      it "redirects to /about with a flash alert" do
        post contact_path, params: valid_params.merge(name: "")
        expect(response).to redirect_to(about_path)
        expect(flash[:alert]).to be_present
      end

      it "sets a flash alert matching the locale value" do
        post contact_path, params: valid_params.merge(name: "")
        expect(flash[:alert]).to eq(I18n.t("contact.errors.missing_required_fields"))
      end

      it "does not send an email" do
        ActionMailer::Base.delivery_method = :test
        ActionMailer::Base.deliveries.clear
        post contact_path, params: valid_params.merge(name: "")
        expect(ActionMailer::Base.deliveries).to be_empty
      end
    end

    context "when email is missing" do
      it "redirects to /about with a flash alert" do
        post contact_path, params: valid_params.merge(email: "")
        expect(response).to redirect_to(about_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "when message is missing" do
      it "redirects to /about with a flash alert" do
        post contact_path, params: valid_params.merge(message: "")
        expect(response).to redirect_to(about_path)
        expect(flash[:alert]).to be_present
      end
    end
  end
end
