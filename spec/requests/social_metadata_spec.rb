require "rails_helper"

RSpec.describe "Open Graph and Twitter card metadata (SPEC-012 Part F)", type: :request do
  def publish_services_page
    SiteSetting.set("services_page_published", "true")
  end

  def head_of(body)
    Nokogiri::HTML(body).at_css("head")
  end

  def meta_by_property(body, property)
    head_of(body).at_css("meta[property='#{property}']")&.[](:content)
  end

  def meta_by_name(body, name)
    head_of(body).at_css("meta[name='#{name}']")&.[](:content)
  end

  def local_business_image(body)
    script = head_of(body).at_css("script[type='application/ld+json']")
    JSON.parse(script.text).fetch("image")
  end

  describe "when a visitor loads the home page" do
    it "gives Open Graph the page's own title and description (AT33, R39, AC-42)" do
      # Act
      get root_path

      # Assert
      expect(meta_by_property(response.body, "og:title")).to eq(I18n.t("pages.home.meta_title"))
      expect(meta_by_property(response.body, "og:description")).to eq(I18n.t("pages.home.meta_description"))
    end

    it "gives the Twitter card the same title and description (AT33, R39, AC-42)" do
      # Act
      get root_path

      # Assert
      expect(meta_by_name(response.body, "twitter:title")).to eq(I18n.t("pages.home.meta_title"))
      expect(meta_by_name(response.body, "twitter:description")).to eq(I18n.t("pages.home.meta_description"))
    end

    it "points og:url at the page's own canonical URL (AT33, R39, AC-42)" do
      # Act
      get root_path

      # Assert
      canonical = head_of(response.body).at_css("link[rel='canonical']")[:href]
      expect(meta_by_property(response.body, "og:url")).to eq(canonical)
      expect(meta_by_property(response.body, "og:url")).to eq(root_url)
    end

    it "declares a website card of the large-image kind (AT33, R39)" do
      # Act
      get root_path

      # Assert
      expect(meta_by_property(response.body, "og:type")).to eq("website")
      expect(meta_by_property(response.body, "og:site_name")).to eq(I18n.t("application.name"))
      expect(meta_by_name(response.body, "twitter:card")).to eq("summary_large_image")
    end

    it "shares one absolute image with the LocalBusiness schema (AT33, R40, AC-43)" do
      # Act
      get root_path

      # Assert
      share_image = local_business_image(response.body)
      expect(share_image).to match(%r{\Ahttps?://.+/assets/gallery/m45a2849-\w+\.jpg\z})
      expect(meta_by_property(response.body, "og:image")).to eq(share_image)
      expect(meta_by_name(response.body, "twitter:image")).to eq(share_image)
    end
  end

  describe "across all four public pages" do
    it "carries each page's own title into its social tags, never a site-wide default (AT33, R39, AC-42)" do
      # Arrange
      publish_services_page
      pages = {
        root_path => I18n.t("pages.home.meta_title"),
        about_path => I18n.t("pages.about.meta_title"),
        gallery_path => I18n.t("pages.gallery.meta_title"),
        services_path => I18n.t("pages.services.meta_title")
      }

      # Act / Assert
      pages.each do |path, expected_title|
        get path

        expect(meta_by_property(response.body, "og:title")).to eq(expected_title),
          "expected og:title on #{path} to be the page's own title"
        expect(meta_by_name(response.body, "twitter:title")).to eq(expected_title),
          "expected twitter:title on #{path} to be the page's own title"
      end
    end

    it "keeps og:title in step with the rendered title tag on every page (AT33, R39, AC-42)" do
      # Arrange
      publish_services_page

      # Act / Assert
      [ root_path, about_path, gallery_path, services_path ].each do |path|
        get path

        rendered_title = head_of(response.body).at_css("title").text
        expect(meta_by_property(response.body, "og:title")).to eq(rendered_title),
          "expected og:title on #{path} to match its <title>"
      end
    end

    it "gives each page its own og:url (AT33, R39, AC-42)" do
      # Arrange
      publish_services_page
      expected_urls = [ root_url, about_url, gallery_url, services_url ]

      # Act
      social_urls = [ root_path, about_path, gallery_path, services_path ].map { |path|
        get path
        meta_by_property(response.body, "og:url")
      }

      # Assert
      expect(social_urls).to eq(expected_urls)
    end
  end
end
