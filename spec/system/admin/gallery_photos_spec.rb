require "rails_helper"

RSpec.describe "Admin gallery photos list", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  def sign_in_admin(admin)
    visit admin_login_path
    fill_in I18n.t("admin.login.email_label"), with: admin.email
    fill_in I18n.t("admin.login.password_label"), with: "password123"
    click_button I18n.t("admin.login.submit")
    expect(page).to have_current_path(admin_root_path)
  end

  describe "admin gallery photo grid at 375 px viewport (AT26, R20, AC-27)" do
    it "renders with no horizontal scroll, grid-cols-2, and a touch-sized delete control per tile" do
      # Arrange
      admin = create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123")
      create(:gallery_photo, position: 0)
      create(:gallery_photo, position: 1)
      emulate_viewport(width: 375, height: 812)
      sign_in_admin(admin)

      # Act
      visit admin_gallery_photos_path

      # headless Chrome enforces a window-size floor above 375px here, so this
      # asserts the actual (narrower-than-md) viewport never overflows horizontally.
      viewport_width = page.evaluate_script("window.innerWidth")
      document_width = page.evaluate_script("document.documentElement.scrollWidth")
      expect(viewport_width).to be < 768
      expect(document_width).to be <= viewport_width

      # Assert — the draggable grid renders at grid-cols-2 at this viewport width
      grid = find("[data-controller='gallery-sort']")
      expect(grid[:class]).to include("grid-cols-2")

      # Assert — each tile's overlaid Delete control meets a minimum 44x44 px touch target
      delete_link = page.all("a[aria-label='#{I18n.t('admin.gallery_photos.delete')}']").first
      expect(delete_link[:class]).to include("w-11").and include("h-11")

      # Assert — upload submit button carries py-3
      expect(page).to have_button(I18n.t("admin.gallery_photos.save"))
      save_button = find_button(I18n.t("admin.gallery_photos.save"))
      expect(save_button[:class]).to include("py-3")
    end
  end
end
