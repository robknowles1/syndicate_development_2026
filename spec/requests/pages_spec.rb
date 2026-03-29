require "rails_helper"

RSpec.describe "Pages", type: :request do
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
