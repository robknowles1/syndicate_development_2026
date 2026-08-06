require "rails_helper"

RSpec.describe "Admin pages are never indexable (SPEC-012 Part E)", type: :request do
  def sign_in_admin(admin)
    post admin_login_path, params: { email: admin.email, password: "securepassword123" }
  end

  def robots_meta(body)
    Nokogiri::HTML(body).at_css("head meta[name='robots']")
  end

  describe "when an authenticated admin loads an admin page" do
    it "marks every admin page noindex, nofollow (AT32, R36, AC-41, E16)" do
      # Arrange
      sign_in_admin(create(:admin_user))
      admin_pages = [
        admin_root_path,
        admin_home_page_content_path,
        admin_faqs_path,
        admin_business_hours_path
      ]

      # Act / Assert
      admin_pages.each do |path|
        get path

        expect(robots_meta(response.body)&.[](:content)).to eq("noindex, nofollow"),
          "expected a noindex, nofollow robots meta tag on #{path}"
      end
    end
  end

  describe "when a crawler reaches an admin page with no session" do
    it "still marks the login page noindex, nofollow (AT32, R36, AC-41, E16)" do
      # Arrange — no sign-in

      # Act
      get admin_login_path

      # Assert
      expect(robots_meta(response.body)&.[](:content)).to eq("noindex, nofollow")
    end
  end

  describe "when a visitor loads a public page" do
    it "leaves the public pages free of any robots meta tag (R36)" do
      # Act
      get root_path

      # Assert
      expect(robots_meta(response.body)).to be_nil
    end
  end
end
