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

  it "opens a lightbox on click and closes it via the close button" do
    # Arrange
    create(:gallery_photo, position: 0)
    visit gallery_path

    # Act
    find("div.grid button").click

    # Assert
    overlay = find("[data-gallery-lightbox-target='overlay']", visible: :all)
    expect(overlay[:class]).not_to include("hidden")

    # Act
    find("button[aria-label='#{I18n.t('pages.gallery.lightbox_close_aria_label')}']").click

    # Assert
    overlay = find("[data-gallery-lightbox-target='overlay']", visible: :all)
    expect(overlay[:class]).to include("hidden")
  end

  it "closes the lightbox when the click target is the backdrop itself, not the image" do
    # Arrange
    create(:gallery_photo, position: 0)
    visit gallery_path
    find("div.grid button").click

    # Act — dispatch a real click event whose target is the overlay node itself,
    # matching the closeOnBackdrop handler's event.target === overlayTarget check
    page.execute_script(<<~JS)
      document.querySelector("[data-gallery-lightbox-target='overlay']").click()
    JS

    # Assert
    overlay = find("[data-gallery-lightbox-target='overlay']", visible: :all)
    expect(overlay[:class]).to include("hidden")
  end

  it "closes the lightbox on pressing Escape" do
    # Arrange
    create(:gallery_photo, position: 0)
    visit gallery_path
    find("div.grid button").click

    # Act
    find("body").send_keys(:escape)

    # Assert
    overlay = find("[data-gallery-lightbox-target='overlay']", visible: :all)
    expect(overlay[:class]).to include("hidden")
  end
end
