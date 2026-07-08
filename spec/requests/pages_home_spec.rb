require "rails_helper"

RSpec.describe "GET / (home page — SPEC-006 content editing)", type: :request do
  describe "when no HomePageContent row exists (AT1, E1)" do
    it "returns HTTP 200 and renders the i18n fallback hero_tagline (AT1, R1, R3)" do
      # Arrange — table empty by default in clean test

      # Act
      get root_path

      # Assert
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("pages.home.hero_tagline"))
    end

    it "renders the i18n fallback mission heading when no row exists (AT1)" do
      # Act
      get root_path

      # Assert
      expect(response.body).to include(I18n.t("pages.home.mission_heading"))
    end

    it "renders the i18n fallback mission subheading when no row exists" do
      # Act
      get root_path

      # Assert
      expect(response.body).to include(I18n.t("pages.home.mission_subheading"))
    end

    it "renders the mission body <p> with whitespace-pre-line class (AT6, R9, AC-6)" do
      # Act
      get root_path

      # Assert — whitespace-pre-line applied regardless of publish state
      expect(response.body).to include("whitespace-pre-line")
    end
  end

  describe "when HomePageContent exists with published: false (AT2, E2)" do
    it "returns HTTP 200 and renders i18n fallback mission_heading (AT2, R1)" do
      # Arrange
      create(:home_page_content, published: false)

      # Act
      get root_path

      # Assert
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("pages.home.mission_heading"))
    end

    it "does NOT render DB hero_tagline when unpublished" do
      # Arrange
      create(:home_page_content, published: false, hero_tagline: "Custom Unpublished Line")

      # Act
      get root_path

      # Assert
      expect(response.body).not_to include("Custom Unpublished Line")
    end
  end

  describe "when HomePageContent exists with published: true (AT3, R2)" do
    it "renders DB values for all 4 editable fields (AT3, R2, R3a)" do
      # Arrange
      create(
        :home_page_content,
        published: true,
        hero_tagline: "Race-Ready.",
        mission_heading: "BUILD FAST.",
        mission_subheading: "BIKES THAT WIN.",
        mission_body: "Custom builds."
      )

      # Act
      get root_path

      # Assert
      expect(response.body).to include("Race-Ready.")
      expect(response.body).to include("BUILD FAST.")
      expect(response.body).to include("BIKES THAT WIN.")
      expect(response.body).to include("Custom builds.")
    end

    it "does NOT render i18n tagline when published with custom value" do
      # Arrange
      create(:home_page_content, published: true, hero_tagline: "Race-Ready.")

      # Act
      get root_path

      # Assert
      expect(response.body).not_to include(I18n.t("pages.home.hero_tagline"))
    end
  end

  describe "hero heading and tagline CSS classes (AT4, R4, R5)" do
    it "hero h1 carries both break-words and md:whitespace-nowrap (AT4, R4, AC-4)" do
      # Act
      get root_path

      # Assert
      expect(response.body).to match(/class="[^"]*break-words[^"]*md:whitespace-nowrap[^"]*"/)
        .or match(/class="[^"]*md:whitespace-nowrap[^"]*break-words[^"]*"/)
    end

    it "hero tagline <p> carries md:truncate (AT4, R5)" do
      # Act
      get root_path

      # Assert
      expect(response.body).to include("md:truncate")
    end
  end

  describe "mission body whitespace-pre-line (AT5, AT6, R9)" do
    it "mission body <p> carries whitespace-pre-line when published with DB value (AT5)" do
      # Arrange
      create(:home_page_content, published: true, mission_body: "First.\nSecond.")

      # Act
      get root_path

      # Assert
      expect(response.body).to include("whitespace-pre-line")
      expect(response.body).to include("First.")
    end

    it "mission body <p> carries whitespace-pre-line even on i18n fallback path (AT6, AC-6)" do
      # Arrange — no HomePageContent row

      # Act
      get root_path

      # Assert
      expect(response.body).to include("whitespace-pre-line")
    end
  end

  describe "non-editable copy always renders from i18n (R1)" do
    it "always renders the hero heading from i18n regardless of publish state" do
      # Arrange
      create(:home_page_content, published: true)

      # Act
      get root_path

      # Assert
      expect(response.body).to include(I18n.t("pages.home.hero_heading"))
    end

    it "always renders the CTA heading from i18n" do
      # Act
      get root_path

      # Assert
      expect(response.body).to include(I18n.t("pages.home.cta_heading"))
    end
  end
end
