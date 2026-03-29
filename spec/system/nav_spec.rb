require "rails_helper"

RSpec.describe "Navigation", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  context "on a mobile viewport (375x667)" do
    before do
      # Resize window BEFORE visiting page so media queries apply immediately
      Capybara.current_session.driver.browser.manage.window.resize_to(375, 667)
      visit root_path
    end

    it "hides the desktop nav links and shows the hamburger button" do
      # Desktop flex link container should not be visible (hidden md:flex)
      expect(page).not_to have_css(".hidden", text: "Home", visible: true)

      # Hamburger button should be visible
      expect(page).to have_css("button[aria-label='Toggle navigation menu']", visible: true)
    end

    it "clicking the hamburger reveals the dropdown with nav links" do
      # Dropdown starts hidden
      expect(page).not_to have_css("[data-nav-target='menu']", visible: true)

      # Click hamburger
      find("button[aria-label='Toggle navigation menu']").click

      # Dropdown should be visible and contain links
      expect(page).to have_css("[data-nav-target='menu']", visible: true)
      within("[data-nav-target='menu']") do
        expect(page).to have_link("Home")
        expect(page).to have_link("About")
        expect(page).to have_link("Gallery")
      end
    end

    it "clicking the hamburger a second time hides the dropdown" do
      hamburger = find("button[aria-label='Toggle navigation menu']")
      hamburger.click
      expect(page).to have_css("[data-nav-target='menu']", visible: true)

      hamburger.click
      expect(page).not_to have_css("[data-nav-target='menu']", visible: true)
    end

    it "clicking a dropdown link closes the dropdown and navigates" do
      find("button[aria-label='Toggle navigation menu']").click
      expect(page).to have_css("[data-nav-target='menu']", visible: true)

      within("[data-nav-target='menu']") do
        click_link "About"
      end

      expect(page).to have_current_path(about_path)
      expect(page).not_to have_css("[data-nav-target='menu']", visible: true)
    end
  end
end
