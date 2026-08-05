require "rails_helper"

RSpec.describe "Admin::Dashboard", type: :request do
  let!(:admin) { create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123") }

  def sign_in_admin
    post admin_login_path, params: { email: admin.email, password: "securepassword123" }
  end

  describe "GET /admin" do
    context "when authenticated" do
      before { sign_in_admin }

      it "returns HTTP 200" do
        get admin_root_path
        expect(response).to have_http_status(:ok)
      end

      it "includes the dashboard heading" do
        get admin_root_path
        expect(response.body).to include(I18n.t("admin.dashboard.heading"))
      end

      it "includes a link to the services management page" do
        get admin_root_path
        expect(response.body).to include(I18n.t("admin.dashboard.services_link"))
      end
    end

    context "when unauthenticated" do
      it "redirects to login" do
        get admin_root_path
        expect(response).to redirect_to(admin_login_path)
      end
    end
  end

  describe "GET /admin links to the dashboard-only admin surfaces" do
    def sign_in_dashboard_admin
      dashboard_admin = create(:admin_user, email: "dashboard-admin@example.com")
      post admin_login_path, params: { email: dashboard_admin.email, password: "securepassword123" }
    end

    context "when authenticated" do
      it "links to FAQs from outside the persistent nav (AT12, AC-12)" do
        # Arrange
        sign_in_dashboard_admin

        # Act
        get admin_root_path
        page = Nokogiri::HTML(response.body)

        # Assert
        expect(page.css("a[href='#{admin_faqs_path}']")).not_to be_empty
        expect(page.css("nav ul a[href='#{admin_faqs_path}']")).to be_empty
      end
    end
  end
end
