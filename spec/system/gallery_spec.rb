require "rails_helper"

RSpec.describe "Gallery page", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  it "renders a grid with multiple images" do
    visit gallery_path
    images = page.all("img")
    expect(images.count).to be > 1
  end
end
