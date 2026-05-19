require "rails_helper"

RSpec.describe "Admin::ServicesPages", type: :request do
  let!(:admin) { create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123") }

  def sign_in_admin
    post admin_login_path, params: { email: admin.email, password: "password123" }
  end

  let!(:section) { create(:service_section, slug: "precision_engines", heading: "PRECISION ENGINES") }

  describe "GET /admin/services_page" do
    context "when authenticated" do
      before { sign_in_admin }

      it "returns HTTP 200" do
        get admin_services_page_path
        expect(response).to have_http_status(:ok)
      end

      it "includes headings for all service sections" do
        get admin_services_page_path
        expect(response.body).to include("PRECISION ENGINES")
      end

      it "shows the current published state" do
        SiteSetting.set("services_page_published", "false")
        get admin_services_page_path
        expect(response.body).to include(I18n.t("admin.services_page.heading"))
      end
    end

    context "when unauthenticated" do
      it "redirects to login" do
        get admin_services_page_path
        expect(response).to redirect_to(admin_login_path)
      end
    end
  end

  describe "PATCH /admin/services_page (toggle)" do
    before do
      sign_in_admin
      SiteSetting.find_or_create_by!(key: "services_page_published") { |s| s.value = "false" }
    end

    it "updates services_page_published to true and redirects with flash notice" do
      patch admin_services_page_path, params: { published: "true" }
      expect(response).to redirect_to(admin_services_page_path)
      expect(flash[:notice]).to eq(I18n.t("admin.services_page.toggle_notice"))
      expect(SiteSetting.get("services_page_published")).to eq("true")
    end

    it "updates services_page_published to false and redirects with flash notice" do
      SiteSetting.set("services_page_published", "true")
      patch admin_services_page_path, params: { published: "false" }
      expect(response).to redirect_to(admin_services_page_path)
      expect(SiteSetting.get("services_page_published")).to eq("false")
    end

    context "when unauthenticated" do
      it "redirects to login" do
        sign_out = -> { delete admin_logout_path }
        sign_out.call
        patch admin_services_page_path, params: { published: "true" }
        expect(response).to redirect_to(admin_login_path)
      end
    end
  end

  describe "PATCH /admin/services_page (content update)" do
    before do
      sign_in_admin
    end

    it "persists new heading and redirects with flash notice" do
      bullet = section.service_bullets.first
      patch admin_services_page_path, params: {
        service_sections: {
          "precision_engines" => {
            heading: "Updated Heading",
            service_bullets_attributes: {
              "0" => { id: bullet.id.to_s, body: bullet.body, position: "0", _destroy: "0" }
            }
          }
        }
      }
      expect(response).to redirect_to(admin_services_page_path)
      expect(flash[:notice]).to eq(I18n.t("admin.services_page.content_notice"))
      expect(section.reload.heading).to eq("Updated Heading")
    end

    it "re-renders with validation error when zero bullets are submitted for a section" do
      bullet = section.service_bullets.first
      patch admin_services_page_path, params: {
        service_sections: {
          "precision_engines" => {
            heading: "PRECISION ENGINES",
            service_bullets_attributes: {
              "0" => { id: bullet.id.to_s, body: bullet.body, position: "0", _destroy: "1" }
            }
          }
        }
      }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t("admin.services_page.validation_error"))
    end
  end
end
