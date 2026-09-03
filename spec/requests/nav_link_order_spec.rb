require "rails_helper"

RSpec.describe "Public navigation", type: :request do
  def link_labels_within(document, selector)
    document.css(selector).css("a").filter_map { |link| link.text.strip.presence }
  end

  def desktop_nav_labels(document)
    link_labels_within(document, "nav")
  end

  def mobile_dropdown_labels(document)
    link_labels_within(document, "[data-nav-target='menu']")
  end

  describe "GET /" do
    context "when the services page is published" do
      it "orders the desktop nav links Home, Services, Gallery, About" do
        # Arrange
        SiteSetting.set("services_page_published", "true")

        # Act
        get root_path

        # Assert
        expect(desktop_nav_labels(response.parsed_body)).to eq(
          [ I18n.t("nav.home"), I18n.t("nav.services"), I18n.t("nav.gallery"), I18n.t("nav.about") ]
        )
      end

      it "orders the mobile dropdown links Home, Services, Gallery, About" do
        # Arrange
        SiteSetting.set("services_page_published", "true")

        # Act
        get root_path

        # Assert
        expect(mobile_dropdown_labels(response.parsed_body)).to eq(
          [ I18n.t("nav.home"), I18n.t("nav.services"), I18n.t("nav.gallery"), I18n.t("nav.about") ]
        )
      end
    end

    context "when the services page is not published" do
      it "orders the desktop nav links Home, Gallery, About" do
        # Arrange
        SiteSetting.set("services_page_published", "false")

        # Act
        get root_path

        # Assert
        expect(desktop_nav_labels(response.parsed_body)).to eq(
          [ I18n.t("nav.home"), I18n.t("nav.gallery"), I18n.t("nav.about") ]
        )
      end

      it "orders the mobile dropdown links Home, Gallery, About" do
        # Arrange
        SiteSetting.set("services_page_published", "false")

        # Act
        get root_path

        # Assert
        expect(mobile_dropdown_labels(response.parsed_body)).to eq(
          [ I18n.t("nav.home"), I18n.t("nav.gallery"), I18n.t("nav.about") ]
        )
      end
    end
  end
end
