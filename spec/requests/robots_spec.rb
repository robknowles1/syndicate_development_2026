require "rails_helper"

RSpec.describe "GET /robots.txt (SPEC-012 Part E)", type: :request do
  def pretend_environment_is(name)
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new(name))
  end

  def lines(body)
    body.lines.map(&:strip).reject(&:empty?)
  end

  describe "when running in production" do
    it "opens the site to crawlers but keeps them out of /admin (AT29, R34, AC-38)" do
      # Arrange
      pretend_environment_is("production")

      # Act
      get robots_path

      # Assert
      expect(lines(response.body)).to include("Allow: /", "Disallow: /admin")
    end

    it "points crawlers at the sitemap (AT29, R34, AC-38)" do
      # Arrange
      pretend_environment_is("production")

      # Act
      get robots_path

      # Assert
      expect(lines(response.body)).to include("Sitemap: #{sitemap_url}")
    end

    it "groups the rules under a user-agent so a crawler applies them (AT29, R34)" do
      # Arrange
      pretend_environment_is("production")

      # Act
      get robots_path

      # Assert
      expect(lines(response.body).first).to eq("User-agent: *")
    end
  end

  describe "when running outside production" do
    it "disallows everything and grants nothing (AT30, R34, AC-39, E15)" do
      # Act — the test environment is already a non-production environment
      get robots_path

      # Assert
      expect(lines(response.body)).to include("Disallow: /")
      expect(lines(response.body)).to include("User-agent: *")
      expect(lines(response.body)).not_to include(a_string_starting_with("Allow"))
    end

    it "treats staging as uncrawlable, not as a stand-in for production (AT30, R34, AC-39, E15)" do
      # Arrange
      pretend_environment_is("staging")

      # Act
      get robots_path

      # Assert
      expect(lines(response.body)).to include("Disallow: /")
      expect(lines(response.body)).not_to include(a_string_starting_with("Allow"))
      expect(lines(response.body)).not_to include(a_string_starting_with("Sitemap"))
    end
  end

  describe "in every environment" do
    it "serves plain text without an admin session (AT30, R34, R37)" do
      # Arrange — no sign-in

      # Act
      get robots_path

      # Assert
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/plain")
    end
  end
end
