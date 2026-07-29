require "rails_helper"

# End-to-end coverage of the two flows an admin actually walks through in a browser.
# The request specs cover the rules; these confirm the forms render and submit.
RSpec.describe "Admin auth flows", type: :system do
  before do
    driven_by(:selenium_chrome_headless)
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.deliveries.clear
    # The reset mail is enqueued rather than delivered inline, and the request runs in the
    # server thread, so nothing here can wrap the enqueue in perform_enqueued_jobs.
    ActiveJob::Base.queue_adapter = :inline
  end

  # queue_adapter= is global state; left set, it would perform jobs inline for every later
  # example and turn an assertion about enqueueing into an ordering-dependent failure.
  after { ActiveJob::Base.queue_adapter = :test }

  # Returns the path only. The emailed link is absolute against the test host
  # (example.com), and visiting that would send Capybara to the real internet.
  def path_from_last_email(pattern)
    url = ActionMailer::Base.deliveries.last.text_part.decoded[pattern, 0]
    raise "no link matching #{pattern.inspect} in the last email" if url.nil?

    URI.parse(url).request_uri
  end

  def sign_in(email, password)
    visit admin_login_path
    fill_in I18n.t("admin.login.email_label"), with: email
    fill_in I18n.t("admin.login.password_label"), with: password
    click_button I18n.t("admin.login.submit")
    # Capybara does not wait for the navigation a click starts, so a visit that follows can
    # race ahead of the session cookie the login response is still setting.
    expect(page).to have_current_path(admin_root_path)
  end

  it "invites an admin, who sets a password and lands signed in" do
    # Arrange
    sign_in(create(:admin_user, email: "existing@example.com").email, "securepassword123")

    # Act — invite
    visit new_admin_user_path
    fill_in I18n.t("admin.users.email_label"), with: "newcolleague@example.com"
    click_button I18n.t("admin.users.invite_submit")

    # Assert — invitation recorded and sent
    expect(page).to have_content("newcolleague@example.com")
    expect(ActionMailer::Base.deliveries.last.to).to eq([ "newcolleague@example.com" ])

    # Act — the invitee opens the emailed link in a fresh session
    invite_path = path_from_last_email(%r{https?://\S+/admin/invitation/claim\?token=\S+})
    Capybara.reset_sessions!
    visit invite_path
    fill_in I18n.t("admin.password_fields.password_label"), with: "invitee-chosen-password"
    fill_in I18n.t("admin.password_fields.confirmation_label"), with: "invitee-chosen-password"
    click_button I18n.t("admin.invitation.submit")

    # Assert — signed straight in
    expect(page).to have_content(I18n.t("admin.dashboard.heading"))
    expect(AdminUser.find_by(email: "newcolleague@example.com").active?).to be(true)
  end

  it "resets a forgotten password and signs in with the new one" do
    # Arrange
    create(:admin_user, email: "forgetful@example.com")

    # Act — request the reset from the login page
    visit admin_login_path
    click_link I18n.t("admin.login.forgot_password")
    fill_in I18n.t("admin.password_reset.email_label"), with: "forgetful@example.com"
    click_button I18n.t("admin.password_reset.submit")

    # Assert
    expect(page).to have_content(I18n.t("admin.password_reset.sent"))

    # Act — follow the emailed link and choose a new password
    reset_path = path_from_last_email(%r{https?://\S+/admin/password_reset/claim\?token=\S+})
    visit reset_path
    fill_in I18n.t("admin.password_fields.password_label"), with: "a-freshly-chosen-one"
    fill_in I18n.t("admin.password_fields.confirmation_label"), with: "a-freshly-chosen-one"
    click_button I18n.t("admin.password_reset.set_submit")

    # Assert — signed in, and the new password genuinely works on a fresh login
    expect(page).to have_content(I18n.t("admin.dashboard.heading"))

    Capybara.reset_sessions!
    sign_in("forgetful@example.com", "a-freshly-chosen-one")
    expect(page).to have_content(I18n.t("admin.dashboard.heading"))
  end
end
