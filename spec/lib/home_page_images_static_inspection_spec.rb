require "rails_helper"

RSpec.describe "SPEC-013 home page image copy and alt-text inspection" do
  describe "file-size copy after the shared cap was raised (AT22, R9, AC-23)" do
    it "states 30 MB in every hint and error message that names the limit" do
      # Arrange
      size_bearing_keys = [
        "activerecord.errors.messages.file_too_large",
        "admin.gallery_photos.image_hint",
        "admin.about_page_content.slideshow_image_hint",
        "admin.home_page_content.image_hint"
      ]

      # Act
      messages = size_bearing_keys.index_with { |key| I18n.t(key) }

      # Assert
      expect(messages.values).to all(include("30 MB"))
      expect(messages.values.grep(/15 MB/)).to be_empty
    end

    it "leaves no stale 15 MB figure anywhere in the locale files (R9)" do
      # Arrange
      locale_files = Rails.root.glob("config/locales/**/*.yml")

      # Act
      stale_lines = locale_files.flat_map { |file|
        file.readlines.grep(/15\s*MB/i).map { |line| "#{file.basename}: #{line.strip}" }
      }

      # Assert
      expect(stale_lines).to be_empty
    end

    it "warns in the restore confirmation that uploaded images are removed too (AT22, R18)" do
      # Arrange / Act
      confirmation_text = I18n.t("admin.home_page_content.confirm_restore_defaults")

      # Assert
      expect(confirmation_text).to match(/image/i)
    end
  end

  describe "hero and CTA sections stay undecorated backgrounds (AT23, R11, AC-24)" do
    it "annotates neither background section with alt text or an aria-label" do
      # Arrange
      home_view_source = Rails.root.join("app/views/pages/home.html.erb").read

      # Act
      background_section_tags = home_view_source.scan(/<section[^>]*background-image[^>]*>/m)

      # Assert
      expect(background_section_tags.length).to eq(2)
      expect(background_section_tags.grep(/alt=|aria-label/)).to be_empty
    end

    it "adds no alt-text field to the admin home form (R11, AC-24)" do
      # Arrange
      admin_form_source = Rails.root.join("app/views/admin/home_page_contents/show.html.erb").read

      # Act
      alt_field_references = admin_form_source.scan(/hero_alt|cta_alt|_alt_|alt_text/i)

      # Assert
      expect(alt_field_references).to be_empty
    end
  end

  describe "admin home form and controller copy (AC-23)" do
    it "contains no hardcoded English string literals outside of t()/I18n.t() calls" do
      # Arrange
      view_file = Rails.root.join("app/views/admin/home_page_contents/show.html.erb")
      controller_file = Rails.root.join("app/controllers/admin/home_page_contents_controller.rb")

      # Act
      static_html = view_file.read.gsub(/<%.*?%>/m, "")
      view_text_nodes = static_html.scan(/>([^<>]+)</).flatten.map(&:strip).reject(&:empty?)
      controller_source = controller_file.read.gsub(/I18n\.t\([^)]*\)/, "")

      # Assert
      suspicious_view_text = view_text_nodes.select { |text| text.match?(/[A-Za-z]{2,} [A-Za-z]{2,}/) }
      expect(suspicious_view_text).to be_empty
      expect(controller_source).not_to match(/["'][A-Za-z]+ [A-Za-z]+/)
    end
  end
end
