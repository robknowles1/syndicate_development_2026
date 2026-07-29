require "rails_helper"

# CLAUDE.md requires every admin view to work on a phone first, and the primary admin
# manages this site from one. A request spec cannot catch a control pushed off-screen, a
# form that forces sideways scrolling, or a tap target that collapses under a flex parent,
# so the six views added with invite-only accounts are measured as rendered.
RSpec.describe "Admin auth views at phone widths", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  # A block-local, not a constant: constants defined inside a describe block land on
  # Object and warn if another spec defines the same name. 375 is the narrowest width
  # Chrome will actually render; emulate_viewport refuses anything below it.
  phone_widths = [ 375, 390, 414 ]

  def sign_in_admin
    admin = create(:admin_user)
    visit admin_login_path
    fill_in I18n.t("admin.login.email_label"), with: admin.email
    fill_in I18n.t("admin.login.password_label"), with: "securepassword123"
    click_button I18n.t("admin.login.submit")
    # Capybara does not wait for the navigation a click starts, so a visit that follows can
    # race ahead of the session cookie the login response is still setting.
    expect(page).to have_current_path(admin_root_path)
    admin
  end

  def invited_admin
    admin = AdminUser.new(email: "invitee@example.com", invited_at: Time.current)
    admin.password = SecureRandom.base58(32)
    admin.save!
    admin
  end

  def expect_usable_at(width)
    expect(horizontal_overflow?).to be(false),
      "the page scrolled sideways at #{width}px"
    expect(any_control_offscreen?).to be(false),
      "a form control fell outside the viewport at #{width}px"
    expect(smallest_tap_target_height).to be >= 44,
      "smallest tap target was #{smallest_tap_target_height}px at #{width}px"
  end

  phone_widths.each do |width|
    it "renders the login page usably at #{width}px" do
      # Arrange
      emulate_viewport(width: width)

      # Act
      visit admin_login_path

      # Assert
      expect_usable_at(width)
    end

    it "renders the forgotten-password request page usably at #{width}px" do
      # Arrange
      emulate_viewport(width: width)

      # Act
      visit new_admin_password_reset_path

      # Assert
      expect_usable_at(width)
    end

    it "renders the choose-a-new-password page usably at #{width}px" do
      # Arrange
      admin = create(:admin_user)
      emulate_viewport(width: width)

      # Act
      visit admin_claim_password_reset_path(token: admin.generate_token_for(:password_reset))

      # Assert
      expect(page).to have_content(I18n.t("admin.password_reset.set_heading"))
      expect_usable_at(width)
    end

    it "renders the invitation acceptance page usably at #{width}px" do
      # Arrange
      admin = invited_admin
      emulate_viewport(width: width)

      # Act
      visit admin_claim_invitation_path(token: admin.generate_token_for(:invitation))

      # Assert
      expect(page).to have_content(I18n.t("admin.invitation.heading"))
      expect_usable_at(width)
    end

    it "renders the admin user list usably at #{width}px" do
      # Arrange — a long address next to a Remove button is what pushes this one sideways
      sign_in_admin
      create(:admin_user, email: "a-really-quite-long-address@some-long-domain.example.com")
      emulate_viewport(width: width)

      # Act
      visit admin_users_path

      # Assert
      expect_usable_at(width)
    end

    it "renders the invite form usably at #{width}px" do
      # Arrange
      sign_in_admin
      emulate_viewport(width: width)

      # Act
      visit new_admin_user_path

      # Assert
      expect_usable_at(width)
    end

    it "renders the change-password page usably at #{width}px" do
      # Arrange
      sign_in_admin
      emulate_viewport(width: width)

      # Act
      visit edit_admin_account_path

      # Assert
      expect_usable_at(width)
    end
  end
end
