require "rails_helper"

RSpec.describe "Admin social media link views at phone widths", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  phone_widths = [ 375, 390 ]

  def sign_in_admin
    admin = create(:admin_user)
    visit admin_login_path
    fill_in I18n.t("admin.login.email_label"), with: admin.email
    fill_in I18n.t("admin.login.password_label"), with: "securepassword123"
    click_button I18n.t("admin.login.submit")
    expect(page).to have_current_path(admin_root_path)
    admin
  end

  def expect_usable_at(width)
    expect(actual_viewport_width).to eq(width),
      "the layout viewport grew to #{actual_viewport_width}px, so content overflowed #{width}px"
    expect(horizontal_overflow?).to be(false),
      "the page scrolled sideways at #{width}px"
    expect(any_control_offscreen?).to be(false),
      "a form control fell outside the viewport at #{width}px"
    expect(smallest_tap_target_height).to be >= 44,
      "smallest tap target was #{smallest_tap_target_height}px at #{width}px"
  end

  phone_widths.each do |width|
    it "renders the link list usably at #{width}px (CLAUDE.md mobile-first)" do
      # Arrange — four row controls beneath a long url is what pushes this one sideways
      sign_in_admin
      create(:social_media_link, platform: "instagram", position: 0,
        url: "https://instagram.com/syndicate_development_pocatello_idaho_custom_performance")
      create(:social_media_link, platform: "facebook", position: 1, active: false)
      emulate_viewport(width: width)

      # Act
      visit admin_social_media_links_path

      # Assert
      expect_usable_at(width)
    end

    it "renders the empty link list usably at #{width}px (AC-10)" do
      # Arrange
      sign_in_admin
      emulate_viewport(width: width)

      # Act
      visit admin_social_media_links_path

      # Assert
      expect(page).to have_text(I18n.t("admin.social_media_links.empty_state"))
      expect_usable_at(width)
    end

    it "renders the new link form usably at #{width}px (AC-16, AC-17)" do
      # Arrange
      sign_in_admin
      emulate_viewport(width: width)

      # Act
      visit new_admin_social_media_link_path

      # Assert
      expect_usable_at(width)
    end
  end

  it "lets an admin add a profile and see it on the public site (R7, R8, AC-11, AC-16)" do
    # Arrange
    sign_in_admin
    emulate_viewport(width: 375)

    # Act
    visit new_admin_social_media_link_path
    select I18n.t("social_media.platforms.youtube"), from: I18n.t("admin.social_media_links.platform_label")
    fill_in I18n.t("admin.social_media_links.url_label"), with: "https://youtube.com/@syndicate"
    click_button I18n.t("admin.social_media_links.save")

    # Assert
    expect(page).to have_text(I18n.t("admin.social_media_links.flash.created"))
    expect(SocialMediaLink.sole).to have_attributes(platform: "youtube", active: true)

    visit root_path
    expect(page).to have_css(
      "[data-social-media-links='footer'] a[aria-label='#{I18n.t('social_media.platforms.youtube')}']"
    )
  end

  it "hides a link from the public site when the admin unticks the visibility box (R6, E2)" do
    # Arrange
    sign_in_admin
    link = create(:social_media_link, platform: "instagram", url: "https://instagram.com/syndicate", position: 0)
    emulate_viewport(width: 375)

    # Act
    visit edit_admin_social_media_link_path(link)
    uncheck I18n.t("admin.social_media_links.active_label")
    click_button I18n.t("admin.social_media_links.save")

    # Assert
    expect(page).to have_text(I18n.t("admin.social_media_links.flash.updated"))
    expect(link.reload.active).to be(false)

    visit root_path
    expect(page).to have_no_css("[data-social-media-links]")
  end
end
