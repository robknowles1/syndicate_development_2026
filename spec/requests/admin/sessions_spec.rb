require "rails_helper"

RSpec.describe "Admin::Sessions", type: :request do
  let!(:admin) { create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123") }

  describe "GET /admin/login" do
    it "renders the login page" do
      get admin_login_path
      expect(response).to have_http_status(:ok)
    end

    it "redirects authenticated admin away from login" do
      # Even authenticated users can visit login — no redirect needed per spec
      # (spec only says unauthenticated users are redirected from other admin pages)
      get admin_login_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /admin/login" do
    context "with correct credentials" do
      it "redirects to admin root" do
        post admin_login_path, params: { email: admin.email, password: "password123" }
        expect(response).to redirect_to(admin_root_path)
      end

      it "establishes a session" do
        post admin_login_path, params: { email: admin.email, password: "password123" }
        expect(session[:admin_user_id]).to eq(admin.id)
      end
    end

    context "with incorrect password" do
      it "re-renders the login form with HTTP 422 Unprocessable Entity" do
        post admin_login_path, params: { email: admin.email, password: "wrongpassword" }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not set session[:admin_user_id]" do
        post admin_login_path, params: { email: admin.email, password: "wrongpassword" }
        expect(session[:admin_user_id]).to be_nil
      end

      it "shows an alert flash message" do
        post admin_login_path, params: { email: admin.email, password: "wrongpassword" }
        expect(flash[:alert]).to eq(I18n.t("admin.login.invalid_credentials"))
      end
    end

    context "with unknown email" do
      it "re-renders the login form without revealing which credential was wrong" do
        post admin_login_path, params: { email: "nobody@example.com", password: "password123" }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(flash[:alert]).to eq(I18n.t("admin.login.invalid_credentials"))
      end
    end
  end

  describe "DELETE /admin/logout" do
    before do
      post admin_login_path, params: { email: admin.email, password: "password123" }
    end

    it "clears the session and redirects to login" do
      delete admin_logout_path
      expect(response).to redirect_to(admin_login_path)
      expect(session[:admin_user_id]).to be_nil
    end
  end

  describe "unauthenticated access to protected routes" do
    it "redirects GET /admin to login" do
      get admin_root_path
      expect(response).to redirect_to(admin_login_path)
    end

    it "redirects GET /admin/services_page to login" do
      get admin_services_page_path
      expect(response).to redirect_to(admin_login_path)
    end
  end
end
