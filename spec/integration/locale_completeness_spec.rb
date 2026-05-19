require "rails_helper"

RSpec.describe "Locale completeness", type: :request do
  # Flatten nested hash into dot-separated key paths, e.g.
  # { en: { nav: { home: "Home" } } } => ["nav.home"]
  def flatten_keys(hash, prefix = nil)
    hash.each_with_object([]) do |(key, value), keys|
      full_key = prefix ? "#{prefix}.#{key}" : key.to_s
      if value.is_a?(Hash)
        keys.concat(flatten_keys(value, full_key))
      else
        keys << full_key
      end
    end
  end

  it "every key in en.yml resolves without raising MissingTranslation" do
    locale_file = Rails.root.join("config/locales/en.yml")
    raw = YAML.load_file(locale_file)

    # Strip the top-level "en" key so paths start from the second level
    en_keys = flatten_keys(raw["en"])

    en_keys.each do |key|
      translation = I18n.t(key, locale: :en)
      expect(translation).not_to match(/translation missing/i),
        "Expected #{key} to be defined in en.yml but got: #{translation}"
    end
  end
end
