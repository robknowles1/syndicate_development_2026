require "rails_helper"

RSpec.describe "Admin service section CRUD", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  let!(:admin) { create(:admin_user, email: "admin@syndicate.com", password: "password123", password_confirmation: "password123") }

  before do
    SiteSetting.find_or_create_by!(key: "services_page_published") { |s| s.value = "false" }
  end

  def sign_in_admin
    visit admin_login_path
    fill_in "Email", with: admin.email
    fill_in "Password", with: "password123"
    click_button I18n.t("admin.login.submit")
    expect(page).to have_current_path(admin_root_path)
  end

  describe "creating a new service section" do
    before { sign_in_admin }

    it "creates a section and redirects to the services page with a flash" do
      visit new_admin_service_section_path

      fill_in I18n.t("admin.service_sections.heading"), with: "Frame Fabrication"
      select "wrench", from: I18n.t("admin.service_sections.icon_key_label")

      # The form renders with one bullet row initially; fill it in
      first_body = find("input[name*='service_bullets_attributes'][name*='[body]']")
      first_body.fill_in with: "Custom chromoly frames"

      click_button I18n.t("admin.service_sections.save")

      expect(page).to have_current_path(admin_services_page_path)
      expect(page).to have_text(I18n.t("admin.service_sections.flash.created"))
      expect(page).to have_text("Frame Fabrication")
    end

    it "shows validation errors when the heading is blank" do
      visit new_admin_service_section_path
      click_button I18n.t("admin.service_sections.save")
      expect(page).to have_text("can't be blank")
    end
  end

  describe "editing a service section" do
    let!(:section) do
      s = ServiceSection.new(heading: "OLD HEADING", icon_key: "wrench", position: 0)
      s.service_bullets.build(body: "Original bullet", position: 0)
      s.save!
      s
    end

    before { sign_in_admin }

    it "updates the section heading and redirects with a flash (AT7)" do
      visit edit_admin_service_section_path(section)

      # Pre-populates with current heading (AC-10)
      expect(page).to have_field(I18n.t("admin.service_sections.heading"), with: "OLD HEADING")

      fill_in I18n.t("admin.service_sections.heading"), with: "NEW HEADING"
      click_button I18n.t("admin.service_sections.save")

      expect(page).to have_current_path(admin_services_page_path)
      expect(page).to have_text(I18n.t("admin.service_sections.flash.updated"))
      expect(section.reload.heading).to eq("NEW HEADING")
    end
  end

  describe "deleting a service section" do
    let!(:section) do
      s = ServiceSection.new(heading: "TO DELETE", icon_key: "wrench", position: 0)
      s.service_bullets.build(body: "Bullet", position: 0)
      s.save!
      s
    end

    before { sign_in_admin }

    it "removes the section after confirmation and shows flash (AT8)" do
      visit admin_services_page_path
      expect(page).to have_text("TO DELETE")

      accept_confirm do
        click_button I18n.t("admin.service_sections.delete"), match: :first
      end

      expect(page).to have_current_path(admin_services_page_path)
      expect(page).to have_text(I18n.t("admin.service_sections.flash.destroyed"))
      expect(page).not_to have_text("TO DELETE")
      expect(ServiceSection.find_by(id: section.id)).to be_nil
    end
  end
end
