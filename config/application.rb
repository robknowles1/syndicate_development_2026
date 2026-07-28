require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module SyndicateDevelopment2026
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Outbound mail settings live here rather than in an initializer because the
    # environment files below need them at boot, and initializers run after those.
    config.x.mail.from = ENV.fetch("MAIL_FROM_ADDRESS", "noreply@mail.syndicate-development.com")

    # Where contact-form submissions land. Production reaches the shop; every other
    # environment reaches the developer, so staging tests never email the customer.
    config.x.mail.contact_recipient = ENV.fetch("CONTACT_RECIPIENT_EMAIL") do
      Rails.env.production? ? "haskettd@live.com" : "robknowles105@gmail.com"
    end

    # Resend requires the literal username "resend" with the API key as the password.
    # Read from the environment first so the key can be rotated without re-encrypting
    # credentials; the encrypted credentials file is the fallback.
    config.x.mail.resend_api_key =
      ENV["RESEND_API_KEY"].presence || Rails.application.credentials.dig(:resend, :api_key)
  end
end
