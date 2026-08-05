require "rails_helper"

RSpec.describe "SPEC-012 About page hours static source inspection" do
  describe "app/views/pages/about.html.erb" do
    it "renders day labels from the public namespace, never the admin one (AT20, R19, AC-23)" do
      # Arrange
      view_source = File.read(Rails.root.join("app/views/pages/about.html.erb"))

      # Act
      admin_lookups = view_source.scan(/admin\.business_hours\.\w+/)

      # Assert
      expect(admin_lookups).to be_empty
    end

    it "contains no hardcoded English day name (AT20, R19, AC-23)" do
      # Arrange
      view_source = File.read(Rails.root.join("app/views/pages/about.html.erb"))

      # Act
      day_literals = BusinessHours::DAYS.select { |day| view_source.match?(/\b#{day.capitalize}\b/) }

      # Assert
      expect(day_literals).to be_empty
    end
  end
end
