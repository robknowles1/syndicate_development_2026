require "rails_helper"

RSpec.describe "Admin::Dashboard", type: :request do
  let!(:admin) { create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123") }

  def sign_in_admin
    post admin_login_path, params: { email: admin.email, password: "password123" }
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
end
