require "rails_helper"

RSpec.describe "Admin login", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  let!(:admin) { create(:admin_user, email: "admin@syndicate.com", password: "password123", password_confirmation: "password123") }

  describe "login form" do
    it "renders email field, password field, and submit button" do
      visit admin_login_path

      expect(page).to have_field("Email")
      expect(page).to have_field("Password")
      expect(page).to have_button(I18n.t("admin.login.submit"))
    end
  end

  describe "with correct credentials" do
    it "redirects to the admin dashboard" do
      visit admin_login_path

      fill_in "Email", with: admin.email
      fill_in "Password", with: "password123"
      click_button I18n.t("admin.login.submit")

      expect(page).to have_current_path(admin_root_path)
      expect(page).to have_text(I18n.t("admin.dashboard.heading"))
    end
  end

  describe "with incorrect credentials" do
    it "stays on the login page and shows the error message" do
      visit admin_login_path

      fill_in "Email", with: admin.email
      fill_in "Password", with: "wrongpassword"
      click_button I18n.t("admin.login.submit")

      expect(page).to have_current_path(admin_login_path)
      expect(page).to have_text(I18n.t("admin.login.invalid_credentials"))
    end
  end

  describe "logout" do
    before do
      visit admin_login_path
      fill_in "Email", with: admin.email
      fill_in "Password", with: "password123"
      click_button I18n.t("admin.login.submit")
    end

    it "returns to the login page after clicking Log Out" do
      click_button I18n.t("admin.layout.logout")
      expect(page).to have_current_path(admin_login_path)
    end
  end
end
