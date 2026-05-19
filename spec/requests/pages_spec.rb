require "rails_helper"

RSpec.describe "Pages", type: :request do
  describe "GET /services" do
    before do
      # Seed the three sections so the page can render
      %w[precision_engines custom_suspension ecu_tuning].each_with_index do |slug, i|
        section = ServiceSection.find_or_create_by!(slug: slug) { |s| s.heading = slug.upcase }
        ServiceBullet.find_or_create_by!(service_section: section, position: 0) { |b| b.body = "Bullet #{i}" }
      end
    end

    context "when services_page_published is true" do
      before { SiteSetting.set("services_page_published", "true") }

      it "returns HTTP 200" do
        get services_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "when services_page_published is false" do
      before { SiteSetting.set("services_page_published", "false") }

      it "redirects to root" do
        get services_path
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET / (home page — nav Services link)" do
    context "when services_page_published is false" do
      before { SiteSetting.set("services_page_published", "false") }

      it "does not include the Services nav link" do
        get root_path
        # Extract only the nav section to check
        expect(response.body).not_to include('href="/services"')
      end
    end

    context "when services_page_published is true" do
      before do
        SiteSetting.set("services_page_published", "true")
        %w[precision_engines].each do |slug|
          section = ServiceSection.find_or_create_by!(slug: slug) { |s| s.heading = "Test" }
          ServiceBullet.find_or_create_by!(service_section: section, position: 0) { |b| b.body = "Bullet" }
        end
      end

      it "includes the Services nav link" do
        get root_path
        expect(response.body).to include('href="/services"')
      end
    end
  end

  describe "GET /" do
    it "returns HTTP 200" do
      get root_path
      expect(response).to have_http_status(:ok)
    end

    it "includes the brand headline" do
      get root_path
      expect(response.body).to include("SYNDICATE DEVELOPMENT")
    end

    it "includes the tagline" do
      get root_path
      expect(response.body).to include("Performance, Passion, Precision.")
    end

    it "includes the mission headline" do
      get root_path
      expect(response.body).to include("DREAM IT. BUILD IT. RIDE IT. LOVE IT.")
    end

    it "includes the CTA link text" do
      get root_path
      expect(response.body).to include("CONTACT THE SHOP")
    end
  end

  describe "GET /about" do
    it "returns HTTP 200" do
      get about_path
      expect(response).to have_http_status(:ok)
    end

    it "includes Doug Haskett in the body" do
      get about_path
      expect(response.body).to include("Doug Haskett")
    end

    it "includes the shop phone number" do
      get about_path
      expect(response.body).to include("208-251-9536")
    end

    it "includes the contact form" do
      get about_path
      expect(response.body).to include("Send Message")
    end
  end

  describe "GET /gallery" do
    it "returns HTTP 200" do
      get gallery_path
      expect(response).to have_http_status(:ok)
    end

    it "includes at least one img tag" do
      get gallery_path
      expect(response.body).to include("<img")
    end
  end
end
