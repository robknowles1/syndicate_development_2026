require "rails_helper"

RSpec.describe "Admin::ServiceSections", type: :request do
  let!(:admin) { create(:admin_user, email: "admin@example.com", password: "password123", password_confirmation: "password123") }

  def sign_in_admin
    post admin_login_path, params: { email: admin.email, password: "password123" }
  end

  describe "GET /admin/service_sections/new" do
    context "when authenticated" do
      before { sign_in_admin }

      it "returns HTTP 200" do
        get new_admin_service_section_path
        expect(response).to have_http_status(:ok)
      end

      it "renders the form" do
        get new_admin_service_section_path
        expect(response.body).to include(I18n.t("admin.service_sections.save"))
      end
    end

    context "when unauthenticated" do
      it "redirects to login" do
        get new_admin_service_section_path
        expect(response).to redirect_to(admin_login_path)
      end
    end
  end

  describe "POST /admin/service_sections (AT6)" do
    before { sign_in_admin }

    let!(:existing_a) { create(:service_section, position: 0) }
    let!(:existing_b) { create(:service_section, position: 1) }

    it "creates a section with position = max+1 and redirects (AT6)" do
      expect {
        post admin_service_sections_path, params: {
          service_section: {
            heading: "Frame Fab",
            icon_key: "wrench",
            service_bullets_attributes: {
              "0" => { body: "Custom chromoly frames", position: "0" }
            }
          }
        }
      }.to change(ServiceSection, :count).by(1)

      expect(response).to redirect_to(admin_services_page_path)
      expect(flash[:notice]).to eq(I18n.t("admin.service_sections.flash.created"))

      new_section = ServiceSection.find_by(heading: "Frame Fab")
      expect(new_section).not_to be_nil
      expect(new_section.position).to eq(2)
    end

    it "returns 422 when no bullets are submitted (AT11)" do
      expect {
        post admin_service_sections_path, params: {
          service_section: {
            heading: "Empty Section",
            icon_key: "wrench",
            service_bullets_attributes: {}
          }
        }
      }.not_to change(ServiceSection, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 422 when icon_key is invalid (AT12)" do
      expect {
        post admin_service_sections_path, params: {
          service_section: {
            heading: "Bad Icon",
            icon_key: "invalid_icon",
            service_bullets_attributes: {
              "0" => { body: "A bullet", position: "0" }
            }
          }
        }
      }.not_to change(ServiceSection, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /admin/service_sections/:id/edit" do
    let!(:section) { create(:service_section, heading: "OLD HEADING", icon_key: "bolt", position: 0) }

    before { sign_in_admin }

    it "returns HTTP 200 and pre-populates form fields (AC-10)" do
      get edit_admin_service_section_path(section)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("OLD HEADING")
    end
  end

  describe "PATCH /admin/service_sections/:id (AT7)" do
    let!(:section) { create(:service_section, heading: "OLD HEADING", icon_key: "bolt", position: 0) }
    let(:bullet) { section.service_bullets.first }

    before { sign_in_admin }

    it "updates heading and redirects (AT7)" do
      patch admin_service_section_path(section), params: {
        service_section: {
          heading: "NEW HEADING",
          icon_key: "bolt",
          service_bullets_attributes: {
            "0" => { id: bullet.id.to_s, body: bullet.body, position: "0", _destroy: "0" }
          }
        }
      }
      expect(response).to redirect_to(admin_services_page_path)
      expect(flash[:notice]).to eq(I18n.t("admin.service_sections.flash.updated"))
      expect(section.reload.heading).to eq("NEW HEADING")
    end
  end

  describe "DELETE /admin/service_sections/:id (AT8)" do
    let!(:section) { create(:service_section, position: 0) }

    before do
      # Ensure 3 bullets
      create(:service_bullet, service_section: section, position: 1)
      create(:service_bullet, service_section: section, position: 2)
      sign_in_admin
    end

    it "destroys section and all bullets, then redirects (AT8)" do
      section_id = section.id
      expect {
        delete admin_service_section_path(section)
      }.to change(ServiceSection, :count).by(-1)
        .and change(ServiceBullet, :count).by(-3)

      expect(response).to redirect_to(admin_services_page_path)
      expect(flash[:notice]).to eq(I18n.t("admin.service_sections.flash.destroyed"))
      expect(ServiceSection.find_by(id: section_id)).to be_nil
    end
  end

  describe "PATCH /admin/service_sections/:id/move_up (AT9, AT10)" do
    let!(:section_a) { create(:service_section, heading: "A", position: 0) }
    let!(:section_b) { create(:service_section, heading: "B", position: 1) }

    before { sign_in_admin }

    it "swaps positions when B is moved up (AT9)" do
      patch move_up_admin_service_section_path(section_b)
      expect(response).to redirect_to(admin_services_page_path)
      expect(section_a.reload.position).to eq(1)
      expect(section_b.reload.position).to eq(0)
    end

    it "is a no-op when the lowest-position section is moved up (AT10)" do
      original_position = section_a.position
      patch move_up_admin_service_section_path(section_a)
      expect(response).to redirect_to(admin_services_page_path)
      expect(section_a.reload.position).to eq(original_position)
    end

    it "handles gapped positions correctly (R9)" do
      # After a deletion, positions might be 0 and 5
      section_b.update_column(:position, 5)
      patch move_up_admin_service_section_path(section_b)
      expect(section_b.reload.position).to eq(0)
      expect(section_a.reload.position).to eq(5)
    end
  end

  describe "PATCH /admin/service_sections/:id/move_down" do
    let!(:section_a) { create(:service_section, heading: "A", position: 0) }
    let!(:section_b) { create(:service_section, heading: "B", position: 1) }

    before { sign_in_admin }

    it "swaps positions when A is moved down" do
      patch move_down_admin_service_section_path(section_a)
      expect(response).to redirect_to(admin_services_page_path)
      expect(section_a.reload.position).to eq(1)
      expect(section_b.reload.position).to eq(0)
    end

    it "is a no-op when the highest-position section is moved down" do
      original_position = section_b.position
      patch move_down_admin_service_section_path(section_b)
      expect(response).to redirect_to(admin_services_page_path)
      expect(section_b.reload.position).to eq(original_position)
    end
  end
end
