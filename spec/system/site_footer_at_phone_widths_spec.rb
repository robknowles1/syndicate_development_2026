require "rails_helper"

RSpec.describe "Site footer at phone widths", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  phone_widths = [ 375, 390 ]

  def footer_right_edge
    page.evaluate_script("Math.ceil(document.querySelector('footer').getBoundingClientRect().right)")
  end

  def background_color_of(selector)
    page.evaluate_script(
      "getComputedStyle(document.querySelector('#{selector}')).backgroundColor"
    )
  end

  phone_widths.each do |width|
    it "keeps the footer inside #{width}px (AT50, R42, AC-59, CLAUDE.md mobile-first)" do
      # Arrange
      emulate_viewport(width: width)

      # Act
      visit root_path

      # Assert
      expect(actual_viewport_width).to eq(width),
        "the layout viewport grew to #{actual_viewport_width}px, so content overflowed #{width}px"
      expect(page).to have_css("footer")
      expect(footer_right_edge).to be <= width
      expect(horizontal_overflow?).to be(false)
    end
  end

  it "paints the footer in the same dark tone as the site header (AT50, R42, AC-59)" do
    # Arrange
    emulate_viewport(width: 375)

    # Act
    visit root_path

    # Assert
    expect(background_color_of("footer")).to eq("rgb(36, 33, 33)")
    expect(background_color_of("footer")).to eq(background_color_of("nav"))
  end
end
