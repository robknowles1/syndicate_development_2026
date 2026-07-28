require "rails_helper"

# Guards the helper itself. Without this, a driver change or a silent CDP failure would
# return every mobile spec to the old behaviour — asking for 375px, receiving 500px, and
# passing anyway — which is the failure mode this helper exists to eliminate.
RSpec.describe "ViewportHelpers", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  # Emulate-then-visit is the order every caller uses, and the order the override
  # reliably settles in: applied to an already-rendered page it can report an
  # intermediate width until the next navigation forces a relayout.
  [ 375, 390, 414 ].each do |width|
    it "applies exactly #{width}px, below Chrome's minimum window size" do
      # Arrange
      emulate_viewport(width: width)

      # Act
      visit root_path

      # Assert
      expect(actual_viewport_width).to eq(width)
    end
  end

  # Deliberately no example calling resize_to for contrast: it permanently shrinks the
  # browser window Capybara shares across examples, and a later override cannot go below
  # that window width — which fails whichever emulated example RSpec's random ordering
  # happens to run next.
end
