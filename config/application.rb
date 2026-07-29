require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require_relative "mail_settings"

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

    # Must be assigned before anything reads credentials: Rails memoises the
    # credentials object on first access and captures this flag then, so setting
    # it in config/environments/*.rb is too late to have any effect. Left off
    # while precompiling assets, where no key is available by design.
    config.require_master_key = !Rails.env.local? && MailSettings.credentials_required?

    # Outbound mail settings live here rather than in an initializer because the
    # environment files below need them at boot, and initializers run after those.
    config.x.mail.from = MailSettings.from_address(override: ENV["MAIL_FROM_ADDRESS"])
    config.x.mail.contact_recipient = MailSettings.contact_recipient(
      rails_env: Rails.env,
      override: ENV["CONTACT_RECIPIENT_EMAIL"]
    )
  end
end
