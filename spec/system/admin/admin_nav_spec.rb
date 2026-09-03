require "rails_helper"

# The admin nav must stay usable at real phone widths, not merely be present in the
# markup. A request spec cannot catch layout overflow, a wrapped header, or a collapsed
# tap target, which is how the first cut of this nav shipped effectively unreachable on
# a phone despite passing its request specs.
RSpec.describe "Admin nav at phone widths", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  # A block-local, not a constant: constants defined inside a describe block land on
  # Object and warn if another spec defines the same name.
  phone_widths = [ 375, 390, 414 ]

  def sign_in_admin
    admin = create(:admin_user)
    visit admin_login_path
    fill_in I18n.t("admin.login.email_label"), with: admin.email
    fill_in I18n.t("admin.login.password_label"), with: "securepassword123"
    click_button I18n.t("admin.login.submit")
    # Capybara does not wait for the navigation a click starts, so a visit that follows can
    # race ahead of the session cookie the login response is still setting.
    expect(page).to have_current_path(admin_root_path)
  end

  def layout_metrics
    page.evaluate_script(<<~JS)
      (() => {
        const links = [...document.querySelectorAll('nav[aria-label="#{I18n.t('admin.layout.nav.aria_label')}"] a')];
        const title = document.querySelector('header span');
        const logout = document.querySelector('header button');
        return {
          count: links.length,
          horizontalOverflow: document.body.scrollWidth > window.innerWidth,
          anyOffscreen: links.some(a => {
            const r = a.getBoundingClientRect();
            return r.right > window.innerWidth + 1 || r.left < -1;
          }),
          minTapHeight: Math.min(...links.map(a => Math.round(a.getBoundingClientRect().height))),
          // Compare vertical centres, not top edges: the header is items-center, so
          // elements of differing heights sit on one row with different tops.
          headerSingleRow: Math.abs(
            (title.getBoundingClientRect().top + title.getBoundingClientRect().bottom) / 2 -
            (logout.getBoundingClientRect().top + logout.getBoundingClientRect().bottom) / 2
          ) <= 4,
          titleWrapped: title.getBoundingClientRect().height > 30
        };
      })()
    JS
  end

  phone_widths.each do |width|
    it "renders every nav item on-screen and tappable at #{width}px" do
      # Arrange
      sign_in_admin
      emulate_viewport(width: width)

      # Act
      visit admin_about_page_content_path
      metrics = layout_metrics

      # Assert
      expect(metrics["count"]).to eq(6)
      expect(metrics["horizontalOverflow"]).to be(false),
        "admin nav caused horizontal document overflow at #{width}px"
      expect(metrics["anyOffscreen"]).to be(false),
        "a nav item fell outside the viewport at #{width}px"
      expect(metrics["minTapHeight"]).to be >= 44,
        "smallest nav tap target was #{metrics['minTapHeight']}px at #{width}px"
    end

    it "keeps the header title and logout button on one unwrapped row at #{width}px" do
      # Arrange — the original bug was the header wrapping into two-line fragments,
      # which produces no overflow and so would pass an overflow-only assertion.
      sign_in_admin
      emulate_viewport(width: width)

      # Act
      visit admin_about_page_content_path
      metrics = layout_metrics

      # Assert
      expect(metrics["headerSingleRow"]).to be(true),
        "header title and logout button fell onto different rows at #{width}px"
      expect(metrics["titleWrapped"]).to be(false),
        "header title wrapped to multiple lines at #{width}px"
    end
  end

  it "navigates to the dashboard from an edit page in one tap" do
    # Arrange
    sign_in_admin
    emulate_viewport(width: 375)
    visit admin_about_page_content_path

    # Act
    click_link I18n.t("admin.layout.nav.dashboard")

    # Assert
    expect(page).to have_current_path(admin_root_path)
    expect(page).to have_content(I18n.t("admin.dashboard.heading"))
  end
end
