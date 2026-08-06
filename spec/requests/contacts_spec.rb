require "rails_helper"

RSpec.describe "Contacts", type: :request do
  def contact_form_token_for(rendered_at)
    Rails.application.message_verifier(:contact_form).generate(rendered_at.to_i)
  end

  def valid_contact_params(overrides = {})
    {
      name: "Jane Rider",
      email: "jane@example.com",
      subject: "Engine build question",
      message: "I would like to enquire about a full engine build.",
      rendered_at: contact_form_token_for(5.seconds.ago)
    }.merge(overrides)
  end

  def forwarded_from(ip_address)
    { "HTTP_X_FORWARDED_FOR" => ip_address }
  end

  def response_signature
    [ response.status, response.location, response.body, flash[:notice], flash[:alert] ]
  end

  def captured_warn_lines
    captured = StringIO.new
    capturing_logger = ActiveSupport::Logger.new(captured)
    capturing_logger.formatter = proc { |severity, _time, _progname, message| "#{severity} #{message}\n" }
    original_logger = Rails.logger
    Rails.logger = capturing_logger
    yield
    captured.string.lines.grep(/\AWARN /).map(&:chomp)
  ensure
    Rails.logger = original_logger
  end

  it "declares no lazy let/let! blocks (AT46, AC-56, testing.md 3.4)" do
    expect(File.read(__FILE__)).not_to match(/^\s*let!?[( ]/)
  end

  describe "POST /contact" do
    context "with valid params" do
      it "redirects to /about" do
        # Arrange
        params = valid_contact_params

        # Act
        post contact_path, params: params

        # Assert
        expect(response).to redirect_to(about_path)
      end

      it "sets a flash notice matching the locale value" do
        # Arrange
        params = valid_contact_params

        # Act
        post contact_path, params: params

        # Assert
        expect(flash[:notice]).to eq(I18n.t("contact.notices.message_sent"))
      end

      it "delivers an email" do
        # Arrange
        ActionMailer::Base.deliveries.clear
        params = valid_contact_params

        # Act
        post contact_path, params: params

        # Assert
        expect(ActionMailer::Base.deliveries.count).to eq(1)
      end

      it "sends email to the shop address" do
        # Arrange
        ActionMailer::Base.deliveries.clear
        params = valid_contact_params

        # Act
        post contact_path, params: params

        # Assert
        expect(ActionMailer::Base.deliveries.last.to).to include("robknowles105@gmail.com")
      end
    end

    context "when name is missing" do
      it "redirects to /about with a flash alert" do
        # Arrange
        params = valid_contact_params(name: "")

        # Act
        post contact_path, params: params

        # Assert
        expect(response).to redirect_to(about_path)
        expect(flash[:alert]).to be_present
      end

      it "sets a flash alert matching the locale value" do
        # Arrange
        params = valid_contact_params(name: "")

        # Act
        post contact_path, params: params

        # Assert
        expect(flash[:alert]).to eq(I18n.t("contact.errors.missing_required_fields"))
      end

      it "does not send an email" do
        # Arrange
        ActionMailer::Base.deliveries.clear
        params = valid_contact_params(name: "")

        # Act
        post contact_path, params: params

        # Assert
        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "tells the visitor what went wrong instead of faking success (AT44, AC-54, R55, E25)" do
        # Arrange
        ActionMailer::Base.deliveries.clear
        params = valid_contact_params(name: "")

        # Act
        post contact_path, params: params

        # Assert
        expect(flash[:alert]).to eq(I18n.t("contact.errors.missing_required_fields"))
        expect(flash[:notice]).to be_nil
        expect(ActionMailer::Base.deliveries).to be_empty
      end
    end

    context "when email is missing" do
      it "redirects to /about with a flash alert" do
        # Arrange
        params = valid_contact_params(email: "")

        # Act
        post contact_path, params: params

        # Assert
        expect(response).to redirect_to(about_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "when message is missing" do
      it "redirects to /about with a flash alert" do
        # Arrange
        params = valid_contact_params(message: "")

        # Act
        post contact_path, params: params

        # Assert
        expect(response).to redirect_to(about_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "when phone is omitted" do
      it "still sends, since phone is optional" do
        # Arrange
        ActionMailer::Base.deliveries.clear
        params = valid_contact_params

        # Act
        post contact_path, params: params

        # Assert
        expect(response).to redirect_to(about_path)
        expect(flash[:notice]).to eq(I18n.t("contact.notices.message_sent"))
        expect(ActionMailer::Base.deliveries.size).to eq(1)
      end
    end

    context "when phone is supplied" do
      it "passes it through to the delivered email" do
        # Arrange
        ActionMailer::Base.deliveries.clear
        params = valid_contact_params(phone: "208-555-0123")

        # Act
        post contact_path, params: params

        # Assert
        expect(ActionMailer::Base.deliveries.last.html_part.body.to_s).to include("208-555-0123")
      end
    end

    context "with a token signed at least two seconds ago" do
      it "sends the enquiry (AT38, AC-48, E22)" do
        # Arrange
        ActionMailer::Base.deliveries.clear
        params = valid_contact_params(rendered_at: contact_form_token_for(2.seconds.ago))

        # Act
        post contact_path, params: params

        # Assert
        expect(response).to redirect_to(about_path)
        expect(flash[:notice]).to eq(I18n.t("contact.notices.message_sent"))
        expect(ActionMailer::Base.deliveries.size).to eq(1)
      end
    end

    context "with the honeypot field filled" do
      it "answers exactly as it answers a genuine submission, sending nothing (AT39, AC-49, R51, R52, R53, E20)" do
        # Arrange
        ActionMailer::Base.deliveries.clear
        post contact_path, params: valid_contact_params
        genuine_signature = response_signature
        deliveries_after_genuine = ActionMailer::Base.deliveries.size

        # Act
        post contact_path, params: valid_contact_params(website: "https://spam.example")

        # Assert
        expect(response_signature).to eq(genuine_signature)
        expect(ActionMailer::Base.deliveries.size).to eq(deliveries_after_genuine)
      end
    end

    context "with a token signed less than two seconds ago" do
      it "returns the fake success response and sends nothing (AT40, AC-50, R54)" do
        # Arrange
        ActionMailer::Base.deliveries.clear
        params = valid_contact_params(rendered_at: contact_form_token_for(Time.current))

        # Act
        post contact_path, params: params

        # Assert
        expect(response).to redirect_to(about_path)
        expect(flash[:notice]).to eq(I18n.t("contact.notices.message_sent"))
        expect(ActionMailer::Base.deliveries).to be_empty
      end
    end

    context "without a valid timing token" do
      it "returns the fake success response when the token is missing (AT41, AC-51, R54, E21)" do
        # Arrange
        ActionMailer::Base.deliveries.clear
        params = valid_contact_params.except(:rendered_at)

        # Act
        post contact_path, params: params

        # Assert
        expect(response).to redirect_to(about_path)
        expect(flash[:notice]).to eq(I18n.t("contact.notices.message_sent"))
        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "returns the fake success response for an unsigned timestamp (AT41, AC-51, R54, E21)" do
        # Arrange
        ActionMailer::Base.deliveries.clear
        params = valid_contact_params(rendered_at: 10.minutes.ago.to_i.to_s)

        # Act
        post contact_path, params: params

        # Assert
        expect(response).to redirect_to(about_path)
        expect(flash[:notice]).to eq(I18n.t("contact.notices.message_sent"))
        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "returns the fake success response for a token signed for another purpose (AT41, AC-51, R54, E21)" do
        # Arrange
        ActionMailer::Base.deliveries.clear
        foreign_token = Rails.application.message_verifier(:something_else).generate(1.hour.ago.to_i)
        params = valid_contact_params(rendered_at: foreign_token)

        # Act
        post contact_path, params: params

        # Assert
        expect(response).to redirect_to(about_path)
        expect(flash[:notice]).to eq(I18n.t("contact.notices.message_sent"))
        expect(ActionMailer::Base.deliveries).to be_empty
      end
    end

    context "when one IP exceeds five submissions in ten minutes" do
      it "sends five and fakes success on the sixth (AT42, AC-52, R48, R49, E23)" do
        # Arrange
        ActionMailer::Base.deliveries.clear

        # Act
        signatures = 6.times.map do |attempt|
          post contact_path, params: valid_contact_params(email: "rider#{attempt}@example.com")
          response_signature
        end

        # Assert
        expect(ActionMailer::Base.deliveries.size).to eq(5)
        expect(signatures.last).to eq(signatures.first)
      end
    end

    context "when one email address exceeds three submissions in ten minutes" do
      it "sends three and fakes success on the fourth, whatever the IP (AT43, AC-53, R48, R49, E24)" do
        # Arrange
        ActionMailer::Base.deliveries.clear

        # Act
        signatures = 4.times.map do |attempt|
          post contact_path, params: valid_contact_params,
            headers: forwarded_from("203.0.113.#{attempt + 1}")
          response_signature
        end

        # Assert
        expect(ActionMailer::Base.deliveries.size).to eq(3)
        expect(signatures.last).to eq(signatures.first)
      end
    end

    context "when the honeypot rejects six submissions from one IP" do
      it "leaves the per-IP allowance untouched for the next genuine visitor (AT58, AC-67, R55)" do
        # Arrange
        ActionMailer::Base.deliveries.clear

        # Act
        6.times { post contact_path, params: valid_contact_params(website: "bot") }
        deliveries_after_honeypot = ActionMailer::Base.deliveries.size
        post contact_path, params: valid_contact_params

        # Assert
        expect(deliveries_after_honeypot).to eq(0)
        expect(flash[:notice]).to eq(I18n.t("contact.notices.message_sent"))
        expect(ActionMailer::Base.deliveries.size).to eq(1)
      end
    end

    context "when the timing check rejects six submissions from one IP" do
      it "leaves the per-IP allowance untouched for the next genuine visitor (AT58, AC-67, R55)" do
        # Arrange
        ActionMailer::Base.deliveries.clear

        # Act
        6.times { post contact_path, params: valid_contact_params(rendered_at: "forged") }
        deliveries_after_timing = ActionMailer::Base.deliveries.size
        post contact_path, params: valid_contact_params

        # Assert
        expect(deliveries_after_timing).to eq(0)
        expect(flash[:notice]).to eq(I18n.t("contact.notices.message_sent"))
        expect(ActionMailer::Base.deliveries.size).to eq(1)
      end
    end

    context "when four submissions in ten minutes leave the email blank" do
      it "keeps telling each visitor what is missing rather than sharing one bucket (AT60, AC-69, R48, E32)" do
        # Arrange
        ActionMailer::Base.deliveries.clear

        # Act
        flashes = 4.times.map do
          post contact_path, params: valid_contact_params(email: "")
          [ flash[:alert], flash[:notice] ]
        end

        # Assert
        expect(flashes).to all(eq([ I18n.t("contact.errors.missing_required_fields"), nil ]))
        expect(ActionMailer::Base.deliveries).to be_empty
      end
    end

    context "when a submission is rejected" do
      it "logs one distinguishable warn line per path and no submitted value (AT59, AC-68, R61)" do
        # Arrange
        enquiry = {
          name: "Jane Rider",
          email: "jane@example.com",
          subject: "Engine build question",
          message: "Please quote me for a full engine build on a 2024 YZ250F."
        }

        # Act
        honeypot = captured_warn_lines do
          post contact_path, params: valid_contact_params(enquiry.merge(website: "bot"))
        end
        timing = captured_warn_lines do
          post contact_path, params: valid_contact_params(enquiry.merge(rendered_at: contact_form_token_for(Time.current)))
        end
        5.times { |attempt| post contact_path, params: valid_contact_params(email: "rider#{attempt}@example.com") }
        per_ip = captured_warn_lines { post contact_path, params: valid_contact_params(enquiry) }
        Rails.cache.clear
        3.times do |attempt|
          post contact_path, params: valid_contact_params(enquiry), headers: forwarded_from("203.0.113.#{attempt + 1}")
        end
        per_email = captured_warn_lines do
          post contact_path, params: valid_contact_params(enquiry), headers: forwarded_from("203.0.113.9")
        end

        # Assert
        expect([ honeypot, timing, per_ip, per_email ].map(&:size)).to eq([ 1, 1, 1, 1 ])
        expect(honeypot.first).to include("reason=honeypot")
        expect(timing.first).to include("reason=timing")
        expect(per_ip.first).to include("reason=rate_limit").and include("limit=contact_per_ip")
        expect(per_email.first).to include("reason=rate_limit").and include("limit=contact_per_email")

        rejection_lines = [ honeypot, timing, per_ip, per_email ].flatten
        expect(rejection_lines.uniq.size).to eq(4)
        enquiry.each_value do |submitted_value|
          expect(rejection_lines.join("\n")).not_to include(submitted_value)
        end
      end
    end
  end
end
