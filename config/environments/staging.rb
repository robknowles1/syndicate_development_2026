require "active_support/core_ext/integer/time"

# Staging mirrors production as closely as possible — the point is to catch what
# production would hit. The deliberate differences are called out below.
Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  config.active_storage.service = :local

  # Both require a terminating proxy in front of the app — see the note in
  # config/environments/production.rb. Without one, admin logins do not persist.
  config.assume_ssl = true
  config.force_ssl = true
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Same proxy topology as production — see the note there on what this does and does not
  # buy. Staging must match, or a header-handling bug shows up first in production.
  config.action_dispatch.trusted_proxies = [
    IPAddr.new("127.0.0.0/8"),
    IPAddr.new("::1/128"),
    IPAddr.new("10.0.0.0/8"),
    IPAddr.new("172.16.0.0/12"),
    IPAddr.new("192.168.0.0/16"),
    IPAddr.new("fc00::/7")
  ].freeze

  # Differs from production: staging logs at debug, since diagnosing a failed deploy
  # matters more here than log volume does.
  config.log_tags = [ :request_id ]
  config.logger = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "debug")

  config.silence_healthcheck_path = "/up"
  config.active_support.report_deprecations = false

  # Same delivery path as production, so an SMTP or DNS problem surfaces here first.
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = {
    host: ENV.fetch("APP_HOST", "staging.syndicate-development.com"),
    protocol: "https"
  }
  config.x.mail.resend_api_key = MailSettings.resend_api_key(override: ENV["RESEND_API_KEY"]) do
    Rails.application.credentials.dig(:resend, :api_key)
  end
  MailSettings.validate_api_key!(
    api_key: config.x.mail.resend_api_key,
    required: MailSettings.credentials_required?
  )

  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = MailSettings.smtp_settings(api_key: config.x.mail.resend_api_key)

  config.i18n.fallbacks = true
  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [ :id ]

  # Staging is not for the public. Without this any hostname pointed at the server
  # would serve the site, including one that indexes it.
  config.hosts << ENV.fetch("APP_HOST", "staging.syndicate-development.com")
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
