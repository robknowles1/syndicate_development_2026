require "rails_helper"

RSpec.describe "layouts/application", type: :view do
  describe "when a page sets none of the metadata content_for blocks (AT24, E10)" do
    it "falls back to the site-wide title and description (R21)" do
      # Act
      render template: "layouts/application"

      # Assert
      head = Nokogiri::HTML(rendered).at_css("head")
      expect(head.at_css("title").text).to eq(I18n.t("application.title"))
      expect(head.at_css("meta[name='description']")[:content]).to eq(I18n.t("application.meta_description"))
    end

    it "falls back to the requested URL for the canonical link (R23, AC-28)" do
      # Arrange
      controller.request.path = "/some-page"

      # Act
      render template: "layouts/application"

      # Assert
      canonical = Nokogiri::HTML(rendered).at_css("head link[rel='canonical']")
      expect(canonical[:href]).to eq("#{controller.request.base_url}/some-page")
    end
  end
end
