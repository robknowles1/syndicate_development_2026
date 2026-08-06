require "rails_helper"

RSpec.describe "GET /sitemap.xml (SPEC-012 Part E)", type: :request do
  def publish_services_page
    SiteSetting.set("services_page_published", "true")
  end

  def parsed(body)
    Nokogiri::XML(body)
  end

  def locations(body)
    parsed(body).remove_namespaces!.css("urlset > url > loc").map(&:text)
  end

  describe "when the services page is unpublished" do
    it "lists the three always-public pages and no /services entry (AT28, R33, AC-35, E11)" do
      # Arrange — no site setting row at all is the unpublished state

      # Act
      get sitemap_path

      # Assert
      expect(response).to have_http_status(:ok)
      expect(locations(response.body)).to eq([ root_url, about_url, gallery_url ])
    end

    it "serves XML under the sitemaps.org namespace (AT28, R33, AC-35)" do
      # Act
      get sitemap_path

      # Assert
      expect(response.media_type).to eq("application/xml")
      root = parsed(response.body).root
      expect(root.name).to eq("urlset")
      expect(root.namespace.href).to eq("http://www.sitemaps.org/schemas/sitemap/0.9")
    end
  end

  describe "when the services page is published" do
    it "adds the /services entry alongside the other three (AT28, R33, AC-36, E11)" do
      # Arrange
      publish_services_page

      # Act
      get sitemap_path

      # Assert
      expect(locations(response.body)).to eq([ root_url, about_url, gallery_url, services_url ])
    end
  end

  describe "in either publication state" do
    it "omits lastmod, changefreq and priority (AT28, R33, AC-37)" do
      # Arrange
      publish_services_page

      # Act
      get sitemap_path

      # Assert
      document = parsed(response.body).remove_namespaces!
      expect(document.css("lastmod, changefreq, priority")).to be_empty
    end

    it "is reachable without an admin session (AT28, R37)" do
      # Arrange — no sign-in

      # Act
      get sitemap_path

      # Assert
      expect(response).to have_http_status(:ok)
      expect(locations(response.body)).to include(root_url)
    end
  end
end
