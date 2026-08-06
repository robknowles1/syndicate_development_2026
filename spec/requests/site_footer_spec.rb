require "rails_helper"

RSpec.describe "Site footer (SPEC-012 Part G)", type: :request do
  def publish_services_page
    SiteSetting.set("services_page_published", "true")
  end

  def footer(body)
    Nokogiri::HTML(body).at_css("body footer")
  end

  describe "when a visitor loads any public page" do
    it "renders the copyright line on all four pages (AT34, R41, AC-44)" do
      # Arrange
      publish_services_page
      expected = I18n.t("application.footer.copyright",
        year: Date.current.year, business_name: I18n.t("application.name"))

      # Act / Assert
      [ root_path, about_path, gallery_path, services_path ].each do |path|
        get path

        expect(footer(response.body)&.text&.squish).to eq(expected),
          "expected the footer copyright on #{path}"
      end
    end

    it "names the business and the current year (AT34, R41, R43, AC-44)" do
      # Act
      get root_path

      # Assert
      expect(footer(response.body).text).to include(I18n.t("application.name"))
      expect(footer(response.body).text).to include(Date.current.year.to_s)
    end

    it "carries no address, phone number or navigation link (AT34, R41, AC-44)" do
      # Act
      get about_path

      # Assert
      expect(footer(response.body).css("a")).to be_empty
      expect(footer(response.body).text).not_to include(I18n.t("pages.about.shop_phone_number"))
      expect(footer(response.body).text).not_to include(I18n.t("pages.about.shop_address"))
    end
  end

  describe "when the calendar year turns over" do
    it "renders each request's own year rather than one fixed at boot (AT35, R43, AC-45)" do
      # Arrange
      rendered_years = []

      # Act
      travel_to(Time.zone.local(2027, 6, 1)) do
        get root_path
        rendered_years << footer(response.body).text[/\d{4}/]
      end
      travel_to(Time.zone.local(2031, 6, 1)) do
        get root_path
        rendered_years << footer(response.body).text[/\d{4}/]
      end

      # Assert
      expect(rendered_years).to eq([ "2027", "2031" ])
    end
  end
end
