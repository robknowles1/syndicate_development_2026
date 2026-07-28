module MailSettings
  class MissingApiKeyError < StandardError; end

  SHOP_RECIPIENT = "haskettd@live.com"
  DEVELOPER_RECIPIENT = "robknowles105@gmail.com"
  DEFAULT_FROM_ADDRESS = "noreply@mail.syndicate-development.com"
  SMTP_ADDRESS = "smtp.resend.com"
  SMTP_PORT = 587
  SMTP_USER_NAME = "resend"

  class << self
    def from_address(override:)
      override.presence || DEFAULT_FROM_ADDRESS
    end

    # The override is honoured only in production because Kamal ships a single
    # config/deploy.yml for every environment: a CONTACT_RECIPIENT_EMAIL set in
    # its `env.clear` block reaches staging too, and would point staging at the
    # customer's inbox.
    def contact_recipient(rails_env:, override:)
      return DEVELOPER_RECIPIENT unless rails_env.to_s == "production"

      override.presence || SHOP_RECIPIENT
    end

    # The credential is yielded rather than passed so a boot that already has
    # RESEND_API_KEY never touches encrypted credentials — under
    # require_master_key that read raises on a host without config/master.key.
    def resend_api_key(override:, &credential)
      override.presence || credential.call.presence
    end

    def validate_api_key!(api_key:, required:)
      return unless required
      return if api_key.present?

      raise MissingApiKeyError, <<~MESSAGE.squish
        No Resend API key resolved. Set RESEND_API_KEY, or supply
        config/master.key (or RAILS_MASTER_KEY) so that resend.api_key can be
        read from encrypted credentials.
      MESSAGE
    end

    # Rails sets SECRET_KEY_BASE_DUMMY while running `assets:precompile`, which
    # the Dockerfile does with RAILS_ENV=production and no config/master.key
    # (.dockerignore excludes it). That boot never delivers mail, so demanding
    # credentials there would break every image build.
    def credentials_required?
      ENV["SECRET_KEY_BASE_DUMMY"].blank?
    end

    def smtp_settings(api_key:)
      {
        address: SMTP_ADDRESS,
        port: SMTP_PORT,
        user_name: SMTP_USER_NAME,
        password: api_key,
        authentication: :plain,
        enable_starttls_auto: true
      }
    end
  end
end
