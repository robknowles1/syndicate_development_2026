require "rails_helper"

RSpec.describe "Admin layout — persistent admin nav bar", type: :request do
  def sign_in_admin(admin)
    post admin_login_path, params: { email: admin.email, password: "securepassword123" }
  end

  def nav(response_body)
    Nokogiri::HTML(response_body).at_css("nav[aria-label='#{I18n.t('admin.layout.nav.aria_label')}']")
  end

  def nav_links(response_body)
    nav(response_body)&.css("a") || []
  end

  # Every admin page the nav must appear on, paired with the nav item that should be
  # marked as the current page while viewing it.
  def admin_pages
    {
      admin_root_path => I18n.t("admin.layout.nav.dashboard"),
      admin_home_page_content_path => I18n.t("admin.layout.nav.home"),
      admin_about_page_content_path => I18n.t("admin.layout.nav.about"),
      admin_gallery_photos_path => I18n.t("admin.layout.nav.gallery"),
      admin_services_page_path => I18n.t("admin.layout.nav.services")
    }
  end

  describe "when authenticated (AT18, R14, R16, R18, AC-16, AC-19, E11)" do
    it "renders the nav with all five destinations on every admin page" do
      # Arrange
      sign_in_admin(create(:admin_user))
      expected_labels = admin_pages.values
      expected_hrefs  = admin_pages.keys

      # Act / Assert
      admin_pages.each_key do |path|
        get path

        links = nav_links(response.body)
        expect(links.map { |a| a.text.strip }).to eq(expected_labels),
          "expected nav labels on #{path}"
        expect(links.map { |a| a["href"] }).to eq(expected_hrefs),
          "expected nav hrefs on #{path}"
      end
    end
  end

  describe "current-page marking (AT19, R15, AC-17, E12)" do
    it "marks only the active destination with aria-current and the active fill" do
      # Arrange
      sign_in_admin(create(:admin_user))

      # Act / Assert
      admin_pages.each do |path, active_label|
        get path

        current = nav_links(response.body).select { |a| a["aria-current"] == "page" }
        expect(current.map { |a| a.text.strip }).to eq([ active_label ]),
          "expected only #{active_label.inspect} marked current on #{path}"
        expect(current.first["class"]).to include("bg-red-600")
      end
    end
  end

  describe "when a form re-renders after a validation failure (AT23, R15, AC-22, E14)" do
    it "keeps the active nav item marked on a non-GET re-render" do
      # Arrange — current_page? matches GET only, so a 422 re-render would lose the mark
      sign_in_admin(create(:admin_user))

      # Act
      patch admin_about_page_content_path,
        params: { about_page_content: { shop_heading: "", bio_body: "x" } }

      # Assert
      expect(response).to have_http_status(:unprocessable_entity)
      current = nav_links(response.body).select { |a| a["aria-current"] == "page" }
      expect(current.map { |a| a.text.strip }).to eq([ I18n.t("admin.layout.nav.about") ])
    end
  end

  describe "when on an admin page with no nav entry of its own (AT24, R15, AC-23, E15)" do
    it "marks Services as active on the service-section sub-pages" do
      # Arrange
      sign_in_admin(create(:admin_user))

      # Act
      get new_admin_service_section_path

      # Assert
      current = nav_links(response.body).select { |a| a["aria-current"] == "page" }
      expect(current.map { |a| a.text.strip }).to eq([ I18n.t("admin.layout.nav.services") ])
    end
  end

  describe "when no active admin session (AT20, R14, AC-18, E10)" do
    it "does not render the nav on the login page" do
      # Arrange — no session

      # Act
      get admin_login_path

      # Assert
      expect(nav(response.body)).to be_nil
    end
  end

  describe "nav markup (AT22, R17, AC-20)" do
    it "gives every item touch-target padding and no hover-gated visibility" do
      # Arrange
      sign_in_admin(create(:admin_user))

      # Act
      get admin_about_page_content_path

      # Assert
      links = nav_links(response.body)
      expect(links).not_to be_empty

      links.each do |link|
        expect(link["class"]).to include("py-3")
        expect(link["class"]).to include("px-3")
        expect(link["class"]).not_to match(/\bhover:(block|inline|inline-block|flex|visible|opacity-100)\b/)
        expect(link["class"]).not_to match(/\b(hidden|invisible|opacity-0)\b/)
      end
    end

    it "wraps rather than scrolling horizontally on narrow viewports" do
      # Arrange
      sign_in_admin(create(:admin_user))

      # Act
      get admin_about_page_content_path

      # Assert — CLAUDE.md forbids horizontal scrolling at any width
      list = nav(response.body).at_css("ul")
      expect(list["class"]).to include("flex-wrap")
      expect(list["class"]).not_to include("overflow-x-auto")
    end
  end
end
