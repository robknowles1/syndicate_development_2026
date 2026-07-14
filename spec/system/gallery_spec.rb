require "rails_helper"

RSpec.describe "Gallery page", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  it "renders a grid with multiple images" do
    # Arrange
    create(:gallery_photo, position: 0)
    create(:gallery_photo, position: 1)

    # Act
    visit gallery_path

    # Assert
    images = page.all("img")
    expect(images.count).to be > 1
  end
end
