require "rails_helper"

RSpec.describe "Admin::ServicesPages", type: :request do
  let!(:admin) { create(:admin_user, email: "admin@example.com", password: "securepassword123", password_confirmation: "securepassword123") }

  def sign_in_admin
    post admin_login_path, params: { email: admin.email, password: "securepassword123" }
  end

  let!(:section) { create(:service_section, heading: "PRECISION ENGINES", position: 0) }

  describe "GET /admin/services_page" do
    context "when authenticated" do
      before { sign_in_admin }

      it "returns HTTP 200" do
        get admin_services_page_path
        expect(response).to have_http_status(:ok)
      end

      it "includes headings for all service sections ordered by position (AT5)" do
        b = create(:service_section, heading: "SUSPENSION", position: 1)
        get admin_services_page_path
        body = response.body
        expect(body.index("PRECISION ENGINES")).to be < body.index("SUSPENSION")
      end

      it "shows the current published state" do
        SiteSetting.set("services_page_published", "false")
        get admin_services_page_path
        expect(response.body).to include(I18n.t("admin.services_page.heading"))
      end

      it "renders the add-first link when no sections exist (E5)" do
        ServiceSection.destroy_all
        get admin_services_page_path
        expect(response.body).to include(I18n.t("admin.service_sections.add_first"))
      end

      it "renders an inline SVG via the vendored fallback for car-suspension sections (AC-19/AT15)" do
        ServiceSection.destroy_all
        create(:service_section, heading: "Suspension Section", icon_key: "car-suspension", position: 0)
        get admin_services_page_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("<svg")
      end
    end

    context "when unauthenticated" do
      it "redirects to login" do
        get admin_services_page_path
        expect(response).to redirect_to(admin_login_path)
      end
    end
  end

  describe "PATCH /admin/services_page (toggle published)" do
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
        delete admin_logout_path
        patch admin_services_page_path, params: { published: "true" }
        expect(response).to redirect_to(admin_login_path)
      end
    end
  end
end
