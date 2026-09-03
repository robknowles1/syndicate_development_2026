require "rails_helper"

RSpec.describe "Social media links at phone widths", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  phone_widths = [ 375, 390, 414 ]

  def create_three_active_links
    create(:social_media_link, platform: "instagram", url: "https://instagram.com/syndicate", position: 0)
    create(:social_media_link, platform: "facebook", url: "https://facebook.com/syndicate", position: 1)
    create(:social_media_link, platform: "youtube", url: "https://youtube.com/@syndicate", position: 2)
  end

  # Measures the rendered boxes rather than asserting on class names, so padding that exists
  # only as a class name cannot pass for a real tap area.
  def tap_area_boxes_at(location)
    page.evaluate_script(<<~JS)
      (() => {
        const links = [...document.querySelectorAll("[data-social-media-links='#{location}'] a")];
        return links.map(link => {
          const icon = link.querySelector('svg').getBoundingClientRect();
          const box = link.getBoundingClientRect();
          return { width: box.width, height: box.height, iconWidth: icon.width, iconHeight: icon.height };
        });
      })()
    JS
  end

  def assert_tap_targets_at_least_44(location, width)
    boxes = tap_area_boxes_at(location)
    expect(boxes.size).to eq(3), "expected 3 links at #{location}"
    boxes.each do |box|
      expect(box["width"]).to be >= 44,
        "#{location} link tap width was #{box['width']}px at #{width}px viewport"
      expect(box["height"]).to be >= 44,
        "#{location} link tap height was #{box['height']}px at #{width}px viewport"
      expect(box["width"]).to be > box["iconWidth"],
        "#{location} link was no wider than its icon at #{width}px"
      expect(box["height"]).to be > box["iconHeight"],
        "#{location} link was no taller than its icon at #{width}px"
    end
  end

  phone_widths.each do |width|
    it "keeps the footer and CTA rows inside #{width}px on the home page (AT31, R19, AC-31)" do
      # Arrange
      create_three_active_links
      emulate_viewport(width: width)

      # Act
      visit root_path

      # Assert
      expect(page).to have_css("[data-social-media-links='footer'] a", count: 3)
      expect(page).to have_css("[data-social-media-links='home-cta'] a", count: 3)
      expect(actual_viewport_width).to eq(width)
      expect(horizontal_overflow?).to be(false),
        "the home page scrolled sideways at #{width}px"
    end

    it "keeps the About page shop-info row inside #{width}px (AT31, R19, AC-31)" do
      # Arrange
      create_three_active_links
      emulate_viewport(width: width)

      # Act
      visit about_path

      # Assert
      expect(page).to have_css("[data-social-media-links='about'] a", count: 3)
      expect(actual_viewport_width).to eq(width)
      expect(horizontal_overflow?).to be(false),
        "the About page scrolled sideways at #{width}px"
    end

    it "gives every footer and CTA icon a 44px tap target at #{width}px (AT31, R19, AC-31)" do
      # Arrange
      create_three_active_links
      emulate_viewport(width: width)

      # Act
      visit root_path

      # Assert
      assert_tap_targets_at_least_44("footer", width)
      assert_tap_targets_at_least_44("home-cta", width)
    end

    it "gives every About page icon a 44px tap target at #{width}px (AT31, R19, AC-31)" do
      # Arrange
      create_three_active_links
      emulate_viewport(width: width)

      # Act
      visit about_path

      # Assert
      assert_tap_targets_at_least_44("about", width)
    end
  end

  it "renders nothing at any location when no links are configured (R14, AC-22, AC-24, AC-26, E1)" do
    # Arrange
    emulate_viewport(width: 375)

    # Act
    visit root_path

    # Assert
    expect(page).to have_css("footer")
    expect(page).to have_no_css("[data-social-media-links]")
  end
end
