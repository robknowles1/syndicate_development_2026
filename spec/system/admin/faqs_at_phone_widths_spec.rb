require "rails_helper"

RSpec.describe "Admin FAQ views at phone widths", type: :system do
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
    it "renders the FAQ list usably at #{width}px (AT48, AC-14)" do
      # Arrange — a long question above four row controls is what pushes this one sideways
      sign_in_admin
      create(:faq, position: 0,
        question: "Do you work on stock or trail bikes, or only race bikes, or something else entirely?",
        answer: "Both, and the answer runs long enough to wrap several times on a narrow phone screen.")
      create(:faq, position: 1)
      emulate_viewport(width: width)

      # Act
      visit admin_faqs_path

      # Assert
      expect_usable_at(width)
    end

    it "renders the empty FAQ list usably at #{width}px (AC-7, AC-14)" do
      # Arrange
      sign_in_admin
      emulate_viewport(width: width)

      # Act
      visit admin_faqs_path

      # Assert
      expect(page).to have_content(I18n.t("admin.faqs.empty_state"))
      expect_usable_at(width)
    end

    it "renders the new FAQ form usably at #{width}px (AT48, AC-14)" do
      # Arrange
      sign_in_admin
      emulate_viewport(width: width)

      # Act
      visit new_admin_faq_path

      # Assert
      expect_usable_at(width)
    end

    it "renders the edit FAQ form usably at #{width}px (AT48, AC-14)" do
      # Arrange
      sign_in_admin
      faq = create(:faq)
      emulate_viewport(width: width)

      # Act
      visit edit_admin_faq_path(faq)

      # Assert
      expect_usable_at(width)
    end
  end
end
