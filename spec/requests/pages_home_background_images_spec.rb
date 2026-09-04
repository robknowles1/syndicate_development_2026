require "rails_helper"

RSpec.describe "Home page hero and CTA background images (SPEC-013)", type: :request do
  def background_image_urls(body)
    Nokogiri::HTML(body)
      .css("section[style*='background-image']")
      .map { |section| section[:style][/url\('([^']+)'\)/, 1] }
  end

  def hero_background_url(body)
    background_image_urls(body).first
  end

  def cta_background_url(body)
    background_image_urls(body).last
  end

  describe "when no HomePageContent row exists" do
    it "falls both sections back to their bundled static assets (AT1, R5, R6, AC-1, E1, E12)" do
      # Arrange — no HomePageContent row

      # Act
      get root_path

      # Assert
      expect(background_image_urls(response.body).length).to eq(2)
      expect(hero_background_url(response.body)).to eq(ActionController::Base.helpers.asset_path("gallery/m45a2849.jpg"))
      expect(cta_background_url(response.body)).to eq(ActionController::Base.helpers.asset_path("gallery/m45a2996.jpg"))
    end
  end

  describe "when published with only the hero slot attached" do
    it "serves the hero from Active Storage and leaves the CTA static (AT2, R1, R3, R6, AC-2, E3)" do
      # Arrange
      create(:home_page_content, :published, :with_hero_image)

      # Act
      get root_path

      # Assert
      expect(hero_background_url(response.body)).to include("/rails/active_storage/representations/")
      expect(cta_background_url(response.body)).to eq(ActionController::Base.helpers.asset_path("gallery/m45a2996.jpg"))
    end
  end

  describe "when published with only the CTA slot attached" do
    it "serves the CTA from Active Storage and leaves the hero static (AT3, R1, R3, R6, AC-3, E4)" do
      # Arrange
      create(:home_page_content, :published, :with_cta_image)

      # Act
      get root_path

      # Assert
      expect(cta_background_url(response.body)).to include("/rails/active_storage/representations/")
      expect(hero_background_url(response.body)).to eq(ActionController::Base.helpers.asset_path("gallery/m45a2849.jpg"))
    end
  end

  describe "when unpublished with both slots attached" do
    it "falls both sections back to their static assets (AT4, R6, R7, AC-4, E2)" do
      # Arrange
      create(:home_page_content, :with_hero_image, :with_cta_image, published: false)

      # Act
      get root_path

      # Assert
      expect(hero_background_url(response.body)).to eq(ActionController::Base.helpers.asset_path("gallery/m45a2849.jpg"))
      expect(cta_background_url(response.body)).to eq(ActionController::Base.helpers.asset_path("gallery/m45a2996.jpg"))
    end
  end

  describe "when published with both slots attached" do
    it "serves both sections from Active Storage, from two distinct representations (AT5, R3, R6, AC-5)" do
      # Arrange
      create(:home_page_content, :published, :with_hero_image, :with_cta_image)

      # Act
      get root_path

      # Assert
      expect(hero_background_url(response.body)).to include("/rails/active_storage/representations/")
      expect(cta_background_url(response.body)).to include("/rails/active_storage/representations/")
      expect(hero_background_url(response.body)).not_to eq(cta_background_url(response.body))
    end
  end
end
