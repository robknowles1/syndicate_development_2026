require "rails_helper"

RSpec.describe "Admin about page content form", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  def sign_in_admin(admin)
    visit admin_login_path
    fill_in I18n.t("admin.login.email_label"),    with: admin.email
    fill_in I18n.t("admin.login.password_label"), with: "password123"
    click_button I18n.t("admin.login.submit")
    expect(page).to have_current_path(admin_root_path)
  end

  describe "admin form at 375 px viewport (AT29, R15, AC-21)" do
    it "renders all form inputs and submit button at mobile viewport without overflow" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      emulate_viewport(width: 375, height: 812)
      sign_in_admin(admin)

      # Act
      visit admin_about_page_content_path

      # Assert — key fields are present and visible
      expect(page).to have_field(I18n.t("admin.about_page_content.shop_heading_label"))
      expect(page).to have_field(I18n.t("admin.about_page_content.shop_phone_label_label"))
      expect(page).to have_field(I18n.t("admin.about_page_content.shop_phone_number_label"))
      expect(page).to have_field(I18n.t("admin.about_page_content.shop_address_label_label"))
      expect(page).to have_field(I18n.t("admin.about_page_content.shop_address_value_label"))
      expect(page).to have_field(I18n.t("admin.about_page_content.bio_heading_label"))
      expect(page).to have_field(I18n.t("admin.about_page_content.bio_body_label"))
      expect(page).to have_field(I18n.t("admin.about_page_content.slideshow_alt_1_label"))
      expect(page).to have_field(I18n.t("admin.about_page_content.slideshow_alt_2_label"))
      expect(page).to have_field(I18n.t("admin.about_page_content.slideshow_alt_3_label"))
      expect(page).to have_button(I18n.t("admin.about_page_content.save"))

      expect(page).to have_text(I18n.t("admin.about_page_content.shop_phone_number_hint"))
      expect(page).to have_text(I18n.t("admin.about_page_content.restore_defaults_label"))
      expect(page).to have_text(I18n.t("admin.about_page_content.published_label"))
    end
  end

  describe "slideshow image file inputs at 375 px viewport (AT14, R13, AC-14)" do
    it "renders the 3 file inputs with w-full and no horizontal scroll" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      emulate_viewport(width: 375, height: 812)
      sign_in_admin(admin)

      # Act
      visit admin_about_page_content_path

      # Assert
      expect(page).to have_field(I18n.t("admin.about_page_content.slideshow_image_1_label"), type: "file")
      expect(page).to have_field(I18n.t("admin.about_page_content.slideshow_image_2_label"), type: "file")
      expect(page).to have_field(I18n.t("admin.about_page_content.slideshow_image_3_label"), type: "file")

      file_inputs = page.all("input[type='file']", visible: :all)
      expect(file_inputs.map { |input| input[:class] }).to all(include("w-full"))

      body_scroll_width = page.evaluate_script("document.body.scrollWidth")
      viewport_width = page.evaluate_script("window.innerWidth")
      expect(body_scroll_width).to be <= viewport_width
    end
  end

  describe "restore defaults button attributes (AT27, R19, AC-27)" do
    it "restore button has data-turbo-confirm, py-3 class, and targets restore_defaults path" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      sign_in_admin(admin)

      # Act
      visit admin_about_page_content_path

      # Assert
      restore_link = find_link(I18n.t("admin.about_page_content.restore_defaults_label"))
      expect(restore_link["href"]).to include(restore_defaults_admin_about_page_content_path)
      expect(restore_link["data-turbo-confirm"]).to eq(I18n.t("admin.about_page_content.confirm_restore_defaults"))
      expect(restore_link["class"]).to include("py-3")
    end
  end

  describe "saving content updates the public about page (E7, R2)" do
    it "published content appears on the public about page after saving" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      create(:about_page_content)
      sign_in_admin(admin)
      visit admin_about_page_content_path

      # Act — fill in form and publish
      fill_in I18n.t("admin.about_page_content.shop_heading_label"), with: "CUSTOM CYCLE SHOP"
      fill_in I18n.t("admin.about_page_content.bio_body_label"), with: "Custom rider bio text."
      check I18n.t("admin.about_page_content.published_label")
      click_button I18n.t("admin.about_page_content.save")

      # Assert — redirected with flash
      expect(page).to have_current_path(admin_about_page_content_path)
      expect(page).to have_text(I18n.t("admin.about_page_content.update_notice"))

      # Verify public page now shows custom content
      visit about_path
      expect(page).to have_text("CUSTOM CYCLE SHOP")
      expect(page).to have_text("Custom rider bio text.")
    end
  end
end
