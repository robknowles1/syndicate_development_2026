require "rails_helper"

RSpec.describe "Social share image follows the uploaded hero (SPEC-013 R12, R13)", type: :request do
  def head_of(body)
    Nokogiri::HTML(body).at_css("head")
  end

  def og_image(body)
    head_of(body).at_css("meta[property='og:image']")&.[](:content)
  end

  def twitter_image(body)
    head_of(body).at_css("meta[name='twitter:image']")&.[](:content)
  end

  def schema_image(body)
    script = head_of(body).at_css("script[type='application/ld+json']")
    JSON.parse(script.text).fetch("image")
  end

  def business_image_url
    Rails.application.routes.url_helpers.root_url(host: "www.example.com").chomp("/") +
      ActionController::Base.helpers.asset_path(StructuredDataHelper::BUSINESS_IMAGE)
  end

  def social_share_variant_url(content)
    Rails.application.routes.url_helpers.rails_representation_url(
      content.social_share_variant, host: "www.example.com"
    )
  end

  describe "when published with hero_image attached" do
    it "points og:image and twitter:image at the hero's social share variant (AT6, R4, R12, AC-6)" do
      # Arrange
      content = create(:home_page_content, :published, :with_hero_image)
      expected_url = social_share_variant_url(content)

      # Act
      get root_path

      # Assert
      expect(og_image(response.body)).to eq(expected_url)
      expect(twitter_image(response.body)).to eq(expected_url)
      expect(expected_url).not_to eq(business_image_url)
    end

    it "gives the schema.org image the exact same URL as og:image (AT6, R13, AC-7)" do
      # Arrange
      create(:home_page_content, :published, :with_hero_image)

      # Act
      get root_path

      # Assert
      expect(schema_image(response.body)).to eq(og_image(response.body))
      expect(schema_image(response.body)).to include("/rails/active_storage/representations/")
    end

    it "resolves to an absolute URL a social scraper can fetch (R12, AC-6)" do
      # Arrange
      create(:home_page_content, :published, :with_hero_image)

      # Act
      get root_path

      # Assert
      expect(og_image(response.body)).to start_with("http://www.example.com/")
    end

    it "uses the 1200x630 social crop, not the 1200x1200 display variant (R4, AC-6)" do
      # Arrange
      content = create(:home_page_content, :published, :with_hero_image)
      display_variant_url = Rails.application.routes.url_helpers.rails_representation_url(
        content.hero_display_variant, host: "www.example.com"
      )

      # Act
      get root_path

      # Assert
      expect(og_image(response.body)).to eq(social_share_variant_url(content))
      expect(og_image(response.body)).not_to eq(display_variant_url)
    end

    it "carries the same hero-derived image onto every other public page (AT6, R13, AC-7)" do
      # Arrange
      content = create(:home_page_content, :published, :with_hero_image)
      expected_url = social_share_variant_url(content)

      # Act / Assert
      [ about_path, gallery_path ].each do |path|
        get path

        expect(og_image(response.body)).to eq(expected_url),
          "expected og:image on #{path} to follow the uploaded hero"
        expect(schema_image(response.body)).to eq(expected_url),
          "expected schema image on #{path} to follow the uploaded hero"
      end
    end
  end

  describe "when hero_image is not attached" do
    it "falls og:image, twitter:image and schema image back to the bundled business image (AT7, R12, R13, AC-8)" do
      # Arrange
      create(:home_page_content, :published)

      # Act
      get root_path

      # Assert
      expect(og_image(response.body)).to eq(business_image_url)
      expect(twitter_image(response.body)).to eq(business_image_url)
      expect(schema_image(response.body)).to eq(business_image_url)
    end

    it "falls back when no HomePageContent row exists at all (AT7, AC-8, E1, E12)" do
      # Arrange — no HomePageContent row

      # Act
      get root_path

      # Assert
      expect(og_image(response.body)).to eq(business_image_url)
      expect(schema_image(response.body)).to eq(business_image_url)
    end
  end

  describe "when unpublished with hero_image attached" do
    it "applies the publish gate to the social image too (AT8, R12, AC-9, E2)" do
      # Arrange
      create(:home_page_content, :with_hero_image, published: false)

      # Act
      get root_path

      # Assert
      expect(og_image(response.body)).to eq(business_image_url)
      expect(twitter_image(response.body)).to eq(business_image_url)
      expect(schema_image(response.body)).to eq(business_image_url)
    end
  end

  describe "when published with only cta_image attached" do
    it "keeps the social image hero-specific rather than any-home-image (AT9, R4, R12, AC-10, E4)" do
      # Arrange
      create(:home_page_content, :published, :with_cta_image)

      # Act
      get root_path

      # Assert
      expect(og_image(response.body)).to eq(business_image_url)
      expect(schema_image(response.body)).to eq(business_image_url)
    end
  end
end
