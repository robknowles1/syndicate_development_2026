require "active_support/core_ext/integer/time"

# Staging mirrors production as closely as possible — the point is to catch what
# production would hit. The deliberate differences are called out below.
Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  config.active_storage.service = :local

  config.assume_ssl = true
  config.force_ssl = true

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
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: "smtp.resend.com",
    port: 587,
    user_name: "resend",
    password: Rails.application.config.x.mail.resend_api_key,
    authentication: :plain,
    enable_starttls_auto: true
  }

  config.i18n.fallbacks = true
  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [ :id ]

  # Staging is not for the public. Without this any hostname pointed at the server
  # would serve the site, including one that indexes it.
  config.hosts << ENV.fetch("APP_HOST", "staging.syndicate-development.com")
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
