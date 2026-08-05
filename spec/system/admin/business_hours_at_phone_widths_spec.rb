require "rails_helper"

RSpec.describe "Admin business hours view at phone widths", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  phone_widths = [ 375, 390 ]

  def sign_in_admin
    admin = create(:admin_user)
    visit admin_login_path
    fill_in I18n.t("admin.login.email_label"), with: admin.email
    fill_in I18n.t("admin.login.password_label"), with: "securepassword123"
    click_button I18n.t("admin.login.submit")
    expect(page).to have_current_path(admin_root_path)
    admin
  end

  # Chrome grows the layout viewport to swallow overflowing content, which is what makes
  # window.innerWidth — and so both helpers below — read clean on a page that overflows.
  # The width the browser ended up at is the measurement that still moves.
  def expect_usable_at(width)
    expect(actual_viewport_width).to eq(width),
      "the layout viewport grew to #{actual_viewport_width}px, so content overflowed #{width}px"
    expect(horizontal_overflow?).to be(false),
      "the page scrolled sideways at #{width}px"
    expect(any_control_offscreen?).to be(false),
      "a form control fell outside the viewport at #{width}px"
    expect(smallest_tap_target_height).to be >= 44,
      "smallest tap target was #{smallest_tap_target_height}px at #{width}px"
  end

  phone_widths.each do |width|
    it "renders the blank hours form usably at #{width}px (AT49, AC-58)" do
      # Arrange — fourteen time inputs paired two-per-row is what pushes this one sideways
      sign_in_admin
      emulate_viewport(width: width)

      # Act
      visit admin_business_hours_path

      # Assert
      expect(page).to have_content(I18n.t("admin.business_hours.heading"))
      expect_usable_at(width)
    end

    it "renders the hours form with saved times usably at #{width}px (AT49, AC-58)" do
      # Arrange
      sign_in_admin
      BusinessHours.create!(monday_opens_at: "08:00", monday_closes_at: "17:00",
        friday_opens_at: "08:00", friday_closes_at: "17:00")
      emulate_viewport(width: width)

      # Act
      visit admin_business_hours_path

      # Assert
      expect_usable_at(width)
    end
  end
end
