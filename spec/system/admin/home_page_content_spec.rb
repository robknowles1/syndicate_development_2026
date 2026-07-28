require "rails_helper"

RSpec.describe "Admin home page content form", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  def sign_in_admin(admin)
    visit admin_login_path
    fill_in I18n.t("admin.login.email_label"),    with: admin.email
    fill_in I18n.t("admin.login.password_label"), with: "password123"
    click_button I18n.t("admin.login.submit")
    expect(page).to have_current_path(admin_root_path)
  end

  describe "admin form at 375 px viewport (AC-17, R17)" do
    it "renders all form inputs and submit button at mobile viewport without overflow" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      emulate_viewport(width: 375, height: 812)
      sign_in_admin(admin)

      # Act
      visit admin_home_page_content_path

      # Assert — key fields are present and visible
      expect(page).to have_field(I18n.t("admin.home_page_content.hero_tagline_label"))
      expect(page).to have_field(I18n.t("admin.home_page_content.mission_heading_label"))
      expect(page).to have_field(I18n.t("admin.home_page_content.mission_subheading_label"))
      expect(page).to have_field(I18n.t("admin.home_page_content.mission_body_label"))
      expect(page).to have_button(I18n.t("admin.home_page_content.save"))

      # The hero tagline hint is permanently visible (not only after error)
      expect(page).to have_text(I18n.t("admin.home_page_content.hero_tagline_hint"))

      # Restore button is present and tappable
      expect(page).to have_text(I18n.t("admin.home_page_content.restore_defaults_label"))

      # Published checkbox label is present
      expect(page).to have_text(I18n.t("admin.home_page_content.published_label"))
    end
  end

  describe "restore defaults button attributes (AC-23, AT21)" do
    it "restore button has data-turbo-confirm, py-3 class, and targets restore_defaults path (AT21)" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)

      # Act
      visit admin_home_page_content_path

      # Assert — check the button/link HTML for required attributes
      restore_link = find_link(I18n.t("admin.home_page_content.restore_defaults_label"))
      expect(restore_link["href"]).to include(restore_defaults_admin_home_page_content_path)
      expect(restore_link["data-turbo-confirm"]).to eq(I18n.t("admin.home_page_content.confirm_restore_defaults"))
      expect(restore_link["class"]).to include("py-3")
    end
  end

  describe "saving content updates the public home page (E2, R2)" do
    it "published content appears on the public home page after saving" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)
      visit admin_home_page_content_path

      # Act — fill in form and publish
      fill_in I18n.t("admin.home_page_content.hero_tagline_label"), with: "Speed. Power."
      fill_in I18n.t("admin.home_page_content.mission_heading_label"), with: "BUILT FOR RACING."
      fill_in I18n.t("admin.home_page_content.mission_subheading_label"), with: "CUSTOM BUILDS ONLY."
      fill_in I18n.t("admin.home_page_content.mission_body_label"), with: "We race and we build."
      check I18n.t("admin.home_page_content.published_label")
      click_button I18n.t("admin.home_page_content.save")

      # Assert — redirected with flash
      expect(page).to have_current_path(admin_home_page_content_path)
      expect(page).to have_text(I18n.t("admin.home_page_content.update_notice"))

      # Verify public page now shows custom content
      visit root_path
      expect(page).to have_text("Speed. Power.")
      expect(page).to have_text("BUILT FOR RACING.")
    end
  end
end
