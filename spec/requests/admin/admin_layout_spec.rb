require "rails_helper"

RSpec.describe "Admin layout — persistent back-to-dashboard navigation", type: :request do
  def sign_in_admin(admin)
    post admin_login_path, params: { email: admin.email, password: "securepassword123" }
  end

  def dashboard_link(response_body)
    Nokogiri::HTML(response_body).at_css("a[href='#{Rails.application.routes.url_helpers.admin_root_path}']")
  end

  describe "when authenticated on a non-dashboard admin page (AT18, R14, R16, E11, AC-16)" do
    it "includes a link to admin_root_path with text from admin.layout.dashboard_link" do
      # Arrange
      admin = create(:admin_user)
      sign_in_admin(admin)

      # Act
      get admin_about_page_content_path

      # Assert
      link = dashboard_link(response.body)
      expect(link).not_to be_nil
      expect(link.text.strip).to eq(I18n.t("admin.layout.dashboard_link"))
    end
  end

  describe "when authenticated on the dashboard itself (AT19, R15, E12, AC-17)" do
    it "does not include the back-to-dashboard link" do
      # Arrange
      admin = create(:admin_user)
      sign_in_admin(admin)

      # Act
      get admin_root_path

      # Assert
      expect(dashboard_link(response.body)).to be_nil
    end
  end

  describe "when no active admin session (AT20, R14, E10, AC-18)" do
    it "does not include the back-to-dashboard link on the login page" do
      # Arrange — no session

      # Act
      get admin_login_path

      # Assert
      expect(dashboard_link(response.body)).to be_nil
    end
  end

  describe "when authenticated across all 4 existing admin edit pages (AT21, R14, R18, AC-19)" do
    it "includes the back-to-dashboard link on every page" do
      # Arrange
      admin = create(:admin_user)
      sign_in_admin(admin)

      # Act / Assert
      get admin_home_page_content_path
      expect(dashboard_link(response.body)).not_to be_nil

      get admin_about_page_content_path
      expect(dashboard_link(response.body)).not_to be_nil

      get admin_gallery_photos_path
      expect(dashboard_link(response.body)).not_to be_nil

      get admin_services_page_path
      expect(dashboard_link(response.body)).not_to be_nil
    end
  end

  describe "back-to-dashboard link markup (AT22, R17, AC-20)" do
    it "carries touch-target padding classes and no hover-only visibility styling" do
      # Arrange
      admin = create(:admin_user)
      sign_in_admin(admin)

      # Act
      get admin_about_page_content_path

      # Assert
      link = dashboard_link(response.body)
      expect(link["class"]).to include("py-3")
      expect(link["class"]).to include("px-4")
      expect(link["class"]).not_to match(/\bhover:(block|inline|inline-block|flex|visible|opacity-100)\b/)
      expect(link["class"]).not_to match(/\b(hidden|invisible|opacity-0)\b/)
    end
  end
end
