require "rails_helper"

RSpec.describe "Pages", type: :request do
  describe "GET /services" do
    context "when services_page_published is true (AT1)" do
      before do
        SiteSetting.set("services_page_published", "true")
        create(:service_section, heading: "SECTION ALPHA",  position: 0, icon_key: "wrench")
        create(:service_section, heading: "SECTION BRAVO",  position: 1, icon_key: "bolt")
        create(:service_section, heading: "SECTION CHARLIE", position: 2, icon_key: "fire")
      end

      it "returns HTTP 200 and renders sections in position order (AT1)" do
        get services_path
        expect(response).to have_http_status(:ok)
        body = response.body
        expect(body).to include("SECTION ALPHA")
        expect(body).to include("SECTION BRAVO")
        expect(body).to include("SECTION CHARLIE")
        expect(body.index("SECTION ALPHA")).to be < body.index("SECTION BRAVO")
        expect(body.index("SECTION BRAVO")).to be < body.index("SECTION CHARLIE")
      end
    end

    context "when services_page_published is false (AT2)" do
      before { SiteSetting.set("services_page_published", "false") }

      it "redirects to root (AT2)" do
        get services_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "icon rendering (AT3)" do
      before do
        SiteSetting.set("services_page_published", "true")
        create(:service_section, heading: "Bolt Section", icon_key: "bolt", position: 0)
      end

      it "renders an inline SVG for the section icon (AT3)" do
        get services_path
        expect(response.body).to include("<svg")
      end
    end

    context "empty sections (AT4)" do
      before { SiteSetting.set("services_page_published", "true") }

      it "returns HTTP 200 with page heading and empty message (AT4)" do
        get services_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("pages.services.heading"))
        expect(response.body).to include(I18n.t("pages.services.empty_message"))
      end
    end
  end

  describe "GET / (home page — nav Services link)" do
    context "when services_page_published is false" do
      before { SiteSetting.set("services_page_published", "false") }

      it "does not include the Services nav link" do
        get root_path
        expect(response.body).not_to include('href="/services"')
      end
    end

    context "when services_page_published is true" do
      before do
        SiteSetting.set("services_page_published", "true")
        create(:service_section, heading: "Test", position: 0)
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
