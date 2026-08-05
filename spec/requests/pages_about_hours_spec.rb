require "rails_helper"

RSpec.describe "GET /about (visible business hours — SPEC-012 T3)", type: :request do
  def hours_list(body)
    Nokogiri::HTML(body).at_css("#shop-hours")
  end

  def listed_days(body)
    hours_list(body).css("li").map { |row| row.css("span").first.text.strip }
  end

  describe "when some days carry hours (E7)" do
    it "lists only those days, in Monday-first order (AT20, R19, AC-23)" do
      # Arrange
      BusinessHours.create!(
        monday_opens_at: "08:00", monday_closes_at: "17:00",
        wednesday_opens_at: "08:00", wednesday_closes_at: "17:00",
        friday_opens_at: "09:00", friday_closes_at: "16:30"
      )

      # Act
      get about_path

      # Assert
      expect(listed_days(response.body)).to eq([
        I18n.t("pages.about.hours.day_monday"),
        I18n.t("pages.about.hours.day_wednesday"),
        I18n.t("pages.about.hours.day_friday")
      ])
    end

    it "renders the heading and each day's span (AT20, R19)" do
      # Arrange
      BusinessHours.create!(monday_opens_at: "08:00", monday_closes_at: "17:30")

      # Act
      get about_path

      # Assert
      expect(response.body).to include(I18n.t("pages.about.hours_heading"))
      expect(hours_list(response.body).text).to include("8:00 AM")
      expect(hours_list(response.body).text).to include("5:30 PM")
    end
  end

  describe "when every day is blank (E6)" do
    it "omits the whole hours block (AT20, R19, AC-22)" do
      # Arrange
      BusinessHours.create!

      # Act
      get about_path

      # Assert
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(I18n.t("pages.about.hours_heading"))
      expect(hours_list(response.body)).to be_nil
    end
  end

  describe "when no BusinessHours row exists (E8)" do
    it "omits the whole hours block without raising (AT20, R19, AC-22)" do
      # Act
      get about_path

      # Assert
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(I18n.t("pages.about.hours_heading"))
      expect(hours_list(response.body)).to be_nil
    end
  end

  describe "the visible hours list and the schema describe the same days (R19, content parity)" do
    it "lists exactly the days openingHoursSpecification claims" do
      # Arrange
      BusinessHours.create!(
        tuesday_opens_at: "08:00", tuesday_closes_at: "17:00",
        thursday_opens_at: "08:00", thursday_closes_at: "17:00"
      )

      # Act
      get about_path

      # Assert
      schema_days = Nokogiri::HTML(response.body)
        .css("script[type='application/ld+json']")
        .map { |script| JSON.parse(script.text) }
        .find { |node| node["@type"] == "MotorcycleRepair" }
        .fetch("openingHoursSpecification")
        .map { |entry| entry["dayOfWeek"].split("/").last }
      expect(listed_days(response.body)).to eq(schema_days)
    end
  end
end
