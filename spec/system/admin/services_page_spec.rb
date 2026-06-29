require "rails_helper"

RSpec.describe "Admin services page toggle", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  let!(:admin) { create(:admin_user, email: "admin@syndicate.com", password: "password123", password_confirmation: "password123") }

  let!(:section) do
    sec = ServiceSection.create!(slug: "precision_engines", heading: "PRECISION ENGINES")
    sec.service_bullets.create!(body: "Full engine builds", position: 0)
    sec
  end

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

  it "toggling published state causes Services nav link to appear on the public home page" do
    sign_in_admin

    # Currently unpublished — nav should not include a services href
    visit root_path
    expect(page).not_to have_link("Services", href: "/services", visible: :any)

    # Go to admin and toggle to published
    visit admin_services_page_path
    expect(page).to have_field(I18n.t("admin.services_page.published_label"), unchecked: true)

    within("#toggle-form") do
      check I18n.t("admin.services_page.published_label")
      click_button I18n.t("admin.services_page.save")
    end

    expect(page).to have_current_path(admin_services_page_path)
    expect(page).to have_text(I18n.t("admin.services_page.toggle_notice"))

    # Now the Services link should be present in the nav HTML
    visit root_path
    expect(page).to have_link("Services", href: "/services", visible: :any)
  end

  it "toggling to unpublished removes the Services nav link" do
    # Start published
    SiteSetting.set("services_page_published", "true")
    sign_in_admin

    visit root_path
    expect(page).to have_link("Services", href: "/services", visible: :any)

    # Go to admin and toggle off
    visit admin_services_page_path
    expect(page).to have_field(I18n.t("admin.services_page.published_label"), checked: true)

    within("#toggle-form") do
      uncheck I18n.t("admin.services_page.published_label")
      click_button I18n.t("admin.services_page.save")
    end

    expect(page).to have_current_path(admin_services_page_path)
    expect(page).to have_text(I18n.t("admin.services_page.toggle_notice"))

    visit root_path
    expect(page).not_to have_link("Services", href: "/services", visible: :any)
  end

  context "public visitor behavior" do
    it "redirects /services to / when unpublished" do
      SiteSetting.set("services_page_published", "false")
      visit services_path
      expect(page).to have_current_path(root_path)
    end

    it "renders /services when published" do
      SiteSetting.set("services_page_published", "true")
      visit services_path
      expect(page).to have_current_path(services_path)
      expect(page).to have_text("PRECISION ENGINES")
    end
  end
end
