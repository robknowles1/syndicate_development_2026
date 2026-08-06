require "rails_helper"

RSpec.describe "Contact form", type: :system do
  before do
    driven_by(:selenium_chrome_headless)
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.deliveries.clear
  end

  def submit_the_form
    submit_button = find("input[type='submit'][value='Send Message']")
    page.execute_script("arguments[0].scrollIntoView({block: 'center'});", submit_button)
    submit_button.click
  end

  it "submitting with valid data shows the success flash notice" do
    visit about_path

    fill_in "Name", with: "Jane Rider"
    fill_in "Email", with: "jane@example.com"
    fill_in "Subject", with: "Build inquiry"
    fill_in "Message", with: "I want to talk about a full build."

    travel 5.seconds
    submit_the_form

    expect(page).to have_text("Message sent! We'll be in touch soon.")
    expect(ActionMailer::Base.deliveries.size).to eq(1)
  end

  it "submits successfully with the optional phone field filled in" do
    visit about_path

    fill_in "Name", with: "Jane Rider"
    fill_in "Email", with: "jane@example.com"
    fill_in "Phone", with: "208-555-0123"
    fill_in "Subject", with: "Build inquiry"
    fill_in "Message", with: "I want to talk about a full build."

    travel 5.seconds
    submit_the_form

    expect(page).to have_text("Message sent! We'll be in touch soon.")
    expect(ActionMailer::Base.deliveries.last.html_part.body.to_s).to include("208-555-0123")
  end

  it "leaves the phone field unmarked as required in the browser" do
    visit about_path

    # The browser must not block submission on a blank phone
    expect(page).to have_css("input[name='phone']")
    expect(page).not_to have_css("input[name='phone'][required]")
  end

  it "submitting with missing required fields shows a flash alert" do
    visit about_path

    # Submit form via JS to bypass HTML5 required attribute validation
    page.execute_script("document.querySelector('form').removeAttribute('novalidate'); arguments[0].removeAttribute('required'); arguments[1].removeAttribute('required'); arguments[2].removeAttribute('required');",
      find("input[name='name']"),
      find("input[name='email']"),
      find("textarea[name='message']"))

    travel 5.seconds
    submit_the_form

    expect(page).to have_css("[role='alert']")
    expect(page).to have_text(I18n.t("contact.errors.missing_required_fields"))
  end

  it "renders the honeypot off screen rather than display:none (AT45, AC-55, R51)" do
    # Arrange
    emulate_viewport(width: 375)

    # Act
    visit about_path
    honeypot = page.evaluate_script(<<~JS)
      (() => {
        const field = document.querySelector("input[name='website']");
        const wrapper = field.parentElement;
        const fieldStyle = getComputedStyle(field);
        const wrapperStyle = getComputedStyle(wrapper);
        return {
          right: Math.ceil(field.getBoundingClientRect().right),
          display: fieldStyle.display,
          visibility: fieldStyle.visibility,
          wrapperDisplay: wrapperStyle.display,
          wrapperVisibility: wrapperStyle.visibility
        };
      })()
    JS

    # Assert
    expect(actual_viewport_width).to eq(375)
    expect(honeypot["right"]).to be < 0
    expect(honeypot["display"]).not_to eq("none")
    expect(honeypot["visibility"]).to eq("visible")
    expect(honeypot["wrapperDisplay"]).not_to eq("none")
    expect(honeypot["wrapperVisibility"]).to eq("visible")
  end

  it "clears the timing threshold with travel, never by blocking on real time (AT47, AC-57, R58)" do
    expect(File.read(__FILE__)).not_to match(/^\s*sleep[\s(]/)
  end
end
