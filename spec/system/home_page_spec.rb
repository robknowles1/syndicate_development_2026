require "rails_helper"

RSpec.describe "Home page", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  it "displays the brand headline and tagline" do
    visit root_path
    expect(page).to have_text("SYNDICATE DEVELOPMENT")
    expect(page).to have_text("Performance, Passion, Precision.")
  end

  it "clicking CONTACT THE SHOP navigates to /about" do
    visit root_path
    link = find_link("CONTACT THE SHOP")
    page.execute_script("arguments[0].scrollIntoView({block: 'center'});", link)
    link.click
    expect(page).to have_current_path(about_path)
    expect(page).to have_text("Doug Haskett")
  end
end
