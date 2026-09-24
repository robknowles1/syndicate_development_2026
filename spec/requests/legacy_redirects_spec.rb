require "rails_helper"

RSpec.describe "Legacy site path redirects (SPEC-017 Phase 7)", type: :request do
  {
    "/projects" => "/gallery",
    "/projects/viewproject/abc123" => "/gallery",
    "/engine" => "/services",
    "/suspension" => "/services",
    "/techtips" => "/",
    "/techtips/viewtip/42" => "/",
    "/auth" => "/admin/login"
  }.each do |old_path, new_path|
    it "permanently redirects #{old_path} to #{new_path}" do
      # Act
      get old_path

      # Assert
      expect(response).to have_http_status(:moved_permanently)
      expect(response.headers["Location"]).to eq("http://www.example.com#{new_path}")
    end
  end

  describe "with a query string" do
    it "carries it through unchanged" do
      # Act
      get "/projects/viewproject/abc123?utm_source=forum&utm_medium=post&tag=a&tag=b"

      # Assert
      expect(response).to have_http_status(:moved_permanently)
      expect(response.headers["Location"])
        .to eq("http://www.example.com/gallery?utm_source=forum&utm_medium=post&tag=a&tag=b")
    end

    it "carries it through to the root without doubling the slash" do
      # Act
      get "/techtips?ref=newsletter"

      # Assert
      expect(response.headers["Location"]).to eq("http://www.example.com/?ref=newsletter")
    end
  end

  describe "without a query string" do
    it "adds no trailing question mark" do
      # Act
      get "/engine"

      # Assert
      expect(response.headers["Location"]).to eq("http://www.example.com/services")
    end
  end

  describe "with paths the old site shares with this one" do
    it "serves /services directly instead of redirecting" do
      # Arrange
      SiteSetting.set("services_page_published", "true")

      # Act
      get "/services"

      # Assert
      expect(response).to have_http_status(:ok)
    end

    it "serves the admin login directly instead of redirecting" do
      # Act
      get "/admin/login"

      # Assert
      expect(response).to have_http_status(:ok)
    end
  end

  describe "with the old site's admin paths" do
    %w[/admin/projects /services-admin /projectsx].each do |path|
      it "leaves #{path} unrouted" do
        # Act
        get path

        # Assert
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
