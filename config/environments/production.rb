require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # REQUIRES A TERMINATING PROXY IN FRONT OF THE APP. `assume_ssl` makes Rails
  # treat every request as HTTPS on the strength of the proxy's headers. Deploy
  # without one (the `proxy:` block in config/deploy.yml is still commented out)
  # and plaintext requests are read as secure: `force_ssl` stops redirecting, and
  # the admin session cookie is marked `Secure` over HTTP, so browsers refuse to
  # send it back and logins silently fail to persist. Enable the proxy first.
  config.assume_ssl = true

  # Marks the admin session cookie `Secure` and sends Strict-Transport-Security.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # kamal-proxy reaches the app over the container network and appends the connecting
  # address to X-Forwarded-For, so the hop it comes in over is what belongs here. Naming
  # the set pins that topology rather than inheriting whatever Rails defaults to. Every
  # range a container network can be allocated from is listed: one that is missing makes
  # the proxy itself look like a client and collapses every caller onto one rate-limit
  # bucket.
  #
  # This narrows who may speak for the client; it does not make remote_ip trustworthy.
  # Anything that reaches the app without passing through the proxy still writes the
  # header freely, which is why no limit here may rest on remote_ip alone.
  config.action_dispatch.trusted_proxies = [
    IPAddr.new("127.0.0.0/8"),
    IPAddr.new("::1/128"),
    IPAddr.new("10.0.0.0/8"),
    IPAddr.new("172.16.0.0/12"),
    IPAddr.new("192.168.0.0/16"),
    IPAddr.new("fc00::/7")
  ].freeze

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  # config.cache_store = :mem_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  # config.active_job.queue_adapter = :resque

  # Surface delivery failures rather than dropping a customer enquiry silently. The
  # contact form delivers synchronously, so a raised error is visible instead of lost.
  config.action_mailer.raise_delivery_errors = true

  # Set host to be used by links generated in mailer templates. Must be the real host —
  # password reset and invitation links are built from it.
  config.action_mailer.default_url_options = {
    host: ENV.fetch("APP_HOST", "www.syndicate-development.com"),
    protocol: "https"
  }

  # Resolved here rather than in config/application.rb so that reading encrypted
  # credentials happens after config.require_master_key is in force.
  config.x.mail.resend_api_key = MailSettings.resend_api_key(override: ENV["RESEND_API_KEY"]) do
    Rails.application.credentials.dig(:resend, :api_key)
  end
  MailSettings.validate_api_key!(
    api_key: config.x.mail.resend_api_key,
    required: MailSettings.credentials_required?
  )

  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = MailSettings.smtp_settings(api_key: config.x.mail.resend_api_key)

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # A Host header not listed here is rejected with 403, so every name that can
  # reach the app must appear. The apex is listed alongside APP_HOST because
  # either name may be pointed at this server; APP_HOST additionally sets the
  # canonical host used for mailer links.
  config.hosts << ENV.fetch("APP_HOST", "www.syndicate-development.com")
  config.hosts << "syndicate-development.com"

  # Skip DNS rebinding protection for the default health check endpoint.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
