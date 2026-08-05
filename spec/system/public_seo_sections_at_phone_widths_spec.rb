require "rails_helper"

RSpec.describe "Home FAQ and About hours at phone widths", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  phone_widths = [ 375, 390 ]

  def expect_no_sideways_scroll_at(width)
    expect(actual_viewport_width).to eq(width),
      "the layout viewport grew to #{actual_viewport_width}px, so content overflowed #{width}px"
    expect(horizontal_overflow?).to be(false),
      "the page scrolled sideways at #{width}px"
  end

  def tallest_element_width
    page.evaluate_script(<<~JS)
      (() => {
        const widths = [...document.querySelectorAll('body *')]
          .map(el => Math.ceil(el.getBoundingClientRect().right));
        return Math.max(...widths);
      })()
    JS
  end

  phone_widths.each do |width|
    it "keeps the FAQ section inside #{width}px with long unbroken answers (R11, CLAUDE.md mobile-first)" do
      # Arrange — an unbroken token is what pushes a <details> body sideways
      create(:faq, position: 0,
        question: "Do you work on stock or trail bikes, or only race bikes, or something else?",
        answer: "Both — suspension, engine and ECU work alike, including verylongunbrokentokenthatcannotwrapnaturally.")
      create(:faq, position: 1)
      emulate_viewport(width: width)

      # Act
      visit root_path
      all("summary").each(&:click)

      # Assert
      expect(page).to have_css("details[open]", count: 2)
      expect_no_sideways_scroll_at(width)
      expect(tallest_element_width).to be <= width
    end

    it "gives every FAQ summary a thumb-sized tap target at #{width}px (CLAUDE.md mobile-first)" do
      # Arrange
      create(:faq, position: 0)
      create(:faq, position: 1)
      emulate_viewport(width: width)

      # Act
      visit root_path

      # Assert
      summary_heights = all("summary").map { |summary| summary.evaluate_script("this.getBoundingClientRect().height") }
      expect(summary_heights).to all(be >= 44)
    end

    it "keeps the hours list inside #{width}px (R19, AC-58 sibling, CLAUDE.md mobile-first)" do
      # Arrange
      BusinessHours.create!(BusinessHours::DAYS.to_h { |day|
        [ "#{day}_opens_at", "08:00" ]
      }.merge(BusinessHours::DAYS.to_h { |day| [ "#{day}_closes_at", "17:30" ] }))
      emulate_viewport(width: width)

      # Act
      visit about_path

      # Assert
      expect(page).to have_css("#shop-hours li", count: 7)
      expect_no_sideways_scroll_at(width)
      expect(tallest_element_width).to be <= width
    end
  end
end
