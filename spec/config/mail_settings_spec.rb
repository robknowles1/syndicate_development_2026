require "rails_helper"

RSpec.describe MailSettings do
  describe ".contact_recipient" do
    context "when the environment is production" do
      it "routes to the shop by default" do
        expect(described_class.contact_recipient(rails_env: "production", override: nil))
          .to eq("haskettd@live.com")
      end

      it "honours an override" do
        expect(described_class.contact_recipient(rails_env: "production", override: "ops@example.com"))
          .to eq("ops@example.com")
      end

      it "falls back to the shop when the override is set but empty" do
        expect(described_class.contact_recipient(rails_env: "production", override: ""))
          .to eq("haskettd@live.com")
      end
    end

    context "when the environment is staging" do
      it "routes to the developer by default" do
        expect(described_class.contact_recipient(rails_env: "staging", override: nil))
          .to eq("robknowles105@gmail.com")
      end

      it "ignores an override that points at the shop" do
        expect(described_class.contact_recipient(rails_env: "staging", override: "haskettd@live.com"))
          .to eq("robknowles105@gmail.com")
      end

      it "ignores an override that points anywhere else" do
        expect(described_class.contact_recipient(rails_env: "staging", override: "ops@example.com"))
          .to eq("robknowles105@gmail.com")
      end
    end

    context "when the environment is development or test" do
      it "routes to the developer regardless of any override" do
        # Arrange
        environments = %w[development test]

        # Act
        recipients = environments.map do |environment|
          described_class.contact_recipient(rails_env: environment, override: "haskettd@live.com")
        end

        # Assert
        expect(recipients).to all(eq("robknowles105@gmail.com"))
      end
    end

    it "accepts the Rails.env string inquirer as well as a plain string" do
      expect(described_class.contact_recipient(rails_env: ActiveSupport::StringInquirer.new("production"), override: nil))
        .to eq("haskettd@live.com")
    end
  end

  describe ".from_address" do
    it "honours an override" do
      expect(described_class.from_address(override: "hello@example.com")).to eq("hello@example.com")
    end

    it "defaults when no override is set" do
      expect(described_class.from_address(override: nil)).to eq("noreply@mail.syndicate-development.com")
    end

    it "defaults when the override is set but empty" do
      expect(described_class.from_address(override: "")).to eq("noreply@mail.syndicate-development.com")
    end
  end

  describe ".resend_api_key" do
    it "prefers the override over the credential" do
      expect(described_class.resend_api_key(override: "re_from_env") { "re_from_credentials" })
        .to eq("re_from_env")
    end

    it "does not read the credential when the override is present" do
      # Arrange
      credential_reads = 0

      # Act
      described_class.resend_api_key(override: "re_from_env") { credential_reads += 1 }

      # Assert
      expect(credential_reads).to eq(0)
    end

    it "falls back to the credential when the override is absent" do
      expect(described_class.resend_api_key(override: nil) { "re_from_credentials" })
        .to eq("re_from_credentials")
    end

    it "falls back to the credential when the override is set but empty" do
      expect(described_class.resend_api_key(override: "") { "re_from_credentials" })
        .to eq("re_from_credentials")
    end

    it "returns nil when neither source supplies a key" do
      expect(described_class.resend_api_key(override: nil) { nil }).to be_nil
    end
  end

  describe ".validate_api_key!" do
    it "raises when the key is missing and credentials are required" do
      expect { described_class.validate_api_key!(api_key: nil, required: true) }
        .to raise_error(MailSettings::MissingApiKeyError, /RESEND_API_KEY/)
    end

    it "raises when the key is blank and credentials are required" do
      expect { described_class.validate_api_key!(api_key: "", required: true) }
        .to raise_error(MailSettings::MissingApiKeyError)
    end

    it "passes when a key is present" do
      expect { described_class.validate_api_key!(api_key: "re_abc123", required: true) }
        .not_to raise_error
    end

    it "passes when the key is missing but credentials are not required" do
      expect { described_class.validate_api_key!(api_key: nil, required: false) }
        .not_to raise_error
    end
  end

  describe ".credentials_required?" do
    it "is false while Rails is precompiling assets" do
      # Arrange
      original = ENV["SECRET_KEY_BASE_DUMMY"]
      ENV["SECRET_KEY_BASE_DUMMY"] = "1"

      # Act
      required = begin
        described_class.credentials_required?
      ensure
        ENV["SECRET_KEY_BASE_DUMMY"] = original
      end

      # Assert
      expect(required).to be(false)
    end

    it "is true on a normal boot" do
      expect(described_class.credentials_required?).to be(true)
    end
  end

  describe ".smtp_settings" do
    it "builds Resend settings with the API key as the password" do
      expect(described_class.smtp_settings(api_key: "re_abc123")).to eq(
        address: "smtp.resend.com",
        port: 587,
        user_name: "resend",
        password: "re_abc123",
        authentication: :plain,
        enable_starttls_auto: true
      )
    end
  end
end
