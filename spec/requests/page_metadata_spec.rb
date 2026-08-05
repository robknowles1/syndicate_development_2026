require "rails_helper"

RSpec.describe "Public page metadata (SPEC-012 Part C)", type: :request do
  def publish_services_page
    SiteSetting.set("services_page_published", "true")
  end

  def head_of(body)
    Nokogiri::HTML(body).at_css("head")
  end

  def title_text(body)
    head_of(body).at_css("title").text
  end

  def meta_description(body)
    head_of(body).at_css("meta[name='description']")[:content]
  end

  def canonical_href(body)
    head_of(body).at_css("link[rel='canonical']")[:href]
  end

  describe "GET /" do
    it "renders the home title and description from i18n (AT22, R21, R22, AC-26)" do
      # Act
      get root_path

      # Assert
      expect(title_text(response.body)).to eq(I18n.t("pages.home.meta_title"))
      expect(meta_description(response.body)).to eq(I18n.t("pages.home.meta_description"))
    end

    it "renders its own canonical URL (AT23, R22, R23, AC-28)" do
      # Act
      get root_path

      # Assert
      expect(canonical_href(response.body)).to eq(root_url)
    end
  end

  describe "GET /about" do
    it "renders the about title and description from i18n (AT22, R22, AC-27)" do
      # Act
      get about_path

      # Assert
      expect(title_text(response.body)).to eq(I18n.t("pages.about.meta_title"))
      expect(meta_description(response.body)).to eq(I18n.t("pages.about.meta_description"))
    end

    it "renders its own canonical URL (AT23, AC-28)" do
      # Act
      get about_path

      # Assert
      expect(canonical_href(response.body)).to eq(about_url)
    end
  end

  describe "GET /gallery" do
    it "renders the gallery title and description from i18n (AT22, R22, AC-27)" do
      # Act
      get gallery_path

      # Assert
      expect(title_text(response.body)).to eq(I18n.t("pages.gallery.meta_title"))
      expect(meta_description(response.body)).to eq(I18n.t("pages.gallery.meta_description"))
    end

    it "renders its own canonical URL (AT23, AC-28)" do
      # Act
      get gallery_path

      # Assert
      expect(canonical_href(response.body)).to eq(gallery_url)
    end
  end

  describe "GET /services" do
    it "renders the services title and description from i18n (AT22, R22, AC-27)" do
      # Arrange
      publish_services_page

      # Act
      get services_path

      # Assert
      expect(title_text(response.body)).to eq(I18n.t("pages.services.meta_title"))
      expect(meta_description(response.body)).to eq(I18n.t("pages.services.meta_description"))
    end

    it "renders its own canonical URL (AT23, AC-28)" do
      # Arrange
      publish_services_page

      # Act
      get services_path

      # Assert
      expect(canonical_href(response.body)).to eq(services_url)
    end
  end

  describe "across all four public pages" do
    it "gives every page a distinct title and description (AT22, AC-27)" do
      # Arrange
      publish_services_page

      # Act
      bodies = [ root_path, about_path, gallery_path, services_path ].map { |path|
        get path
        response.body
      }

      # Assert
      expect(bodies.map { |body| title_text(body) }.uniq.size).to eq(4)
      expect(bodies.map { |body| meta_description(body) }.uniq.size).to eq(4)
    end

    it "keeps the service-area cities out of every title and description (AT22, R24, AC-29)" do
      # Arrange
      publish_services_page
      excluded = [ "Idaho Falls", "Boise", "Utah" ]

      # Act
      metadata = [ root_path, about_path, gallery_path, services_path ].flat_map { |path|
        get path
        [ title_text(response.body), meta_description(response.body) ]
      }

      # Assert
      expect(metadata).to all(satisfy { |text| excluded.none? { |city| text.include?(city) } })
    end
  end
end
