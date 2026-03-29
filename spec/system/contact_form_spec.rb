require "rails_helper"

RSpec.describe "Contact form", type: :system do
  before do
    driven_by(:selenium_chrome_headless)
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.deliveries.clear
  end

  it "submitting with valid data shows the success flash notice" do
    visit about_path

    fill_in "Name", with: "Jane Rider"
    fill_in "Email", with: "jane@example.com"
    fill_in "Subject", with: "Build inquiry"
    fill_in "Message", with: "I want to talk about a full build."

    submit_button = find("input[type='submit'][value='Send Message']")
    page.execute_script("arguments[0].scrollIntoView({block: 'center'});", submit_button)
    submit_button.click

    expect(page).to have_text("Message sent! We'll be in touch soon.")
  end

  it "submitting with missing required fields shows a flash alert" do
    visit about_path

    # Submit form via JS to bypass HTML5 required attribute validation
    page.execute_script("document.querySelector('form').removeAttribute('novalidate'); arguments[0].removeAttribute('required'); arguments[1].removeAttribute('required'); arguments[2].removeAttribute('required');",
      find("input[name='name']"),
      find("input[name='email']"),
      find("textarea[name='message']"))

    submit_button = find("input[type='submit'][value='Send Message']")
    page.execute_script("arguments[0].scrollIntoView({block: 'center'});", submit_button)
    submit_button.click

    expect(page).to have_css("[role='alert']")
  end
end
