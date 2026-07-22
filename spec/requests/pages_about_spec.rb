require "rails_helper"

RSpec.describe "GET /about (about page — SPEC-007 content editing)", type: :request do
  describe "when no AboutPageContent row exists (AT1, E1)" do
    it "returns HTTP 200 and renders the i18n fallback shop_heading (AT1, R1, R3)" do
      # Arrange — table empty by default in clean test

      # Act
      get about_path

      # Assert
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("pages.about.shop_heading"))
    end

    it "renders the i18n fallback bio_heading when no row exists (AT2)" do
      # Act
      get about_path

      # Assert
      expect(response.body).to include(I18n.t("pages.about.bio_heading"))
    end

    it "renders the tel href and visible text from the i18n fallback phone number (AT5)" do
      # Act
      get about_path

      # Assert
      expect(response.body).to include('href="tel:2082519536"')
      expect(response.body).to include("208-251-9536")
    end

    it "renders the bio body <p> with whitespace-pre-line class (AT7, R5, AC-6)" do
      # Act
      get about_path

      # Assert
      expect(response.body).to include("whitespace-pre-line")
    end

    it "renders the 3 slideshow alt attributes from i18n in document order (AT9, R20)" do
      # Act
      get about_path

      # Assert
      body = response.body
      expect(body).to include(%(alt="#{I18n.t("pages.about.slideshow_alt_1")}"))
      expect(body).to include(%(alt="#{I18n.t("pages.about.slideshow_alt_2")}"))
      expect(body).to include(%(alt="#{I18n.t("pages.about.slideshow_alt_3")}"))
      expect(body.index(I18n.t("pages.about.slideshow_alt_1"))).to be < body.index(I18n.t("pages.about.slideshow_alt_2"))
      expect(body.index(I18n.t("pages.about.slideshow_alt_2"))).to be < body.index(I18n.t("pages.about.slideshow_alt_3"))
    end
  end

  describe "when AboutPageContent exists with published: false (AT2, E2)" do
    it "returns HTTP 200 and renders i18n fallback bio_heading (AT2, R1)" do
      # Arrange
      create(:about_page_content, published: false)

      # Act
      get about_path

      # Assert
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("pages.about.bio_heading"))
    end

    it "does NOT render DB shop_heading when unpublished" do
      # Arrange
      create(:about_page_content, published: false, shop_heading: "Custom Unpublished Shop")

      # Act
      get about_path

      # Assert
      expect(response.body).not_to include("Custom Unpublished Shop")
    end
  end

  describe "when AboutPageContent exists with published: true (AT3, R2)" do
    it "renders DB values for all 10 editable fields (AT3, R2, R3a)" do
      # Arrange
      create(
        :about_page_content,
        published: true,
        shop_heading: "CUSTOM SHOP",
        shop_phone_label: "Call Us:",
        shop_phone_number: "555-000-1111",
        shop_address_label: "Find Us:",
        shop_address: "1 Custom Way",
        bio_heading: "About Custom Doug",
        bio_body: "Custom bio body.",
        slideshow_alt_1: "Custom alt one",
        slideshow_alt_2: "Custom alt two",
        slideshow_alt_3: "Custom alt three"
      )

      # Act
      get about_path

      # Assert
      body = response.body
      expect(body).to include("CUSTOM SHOP")
      expect(body).to include("Call Us:")
      expect(body).to include("555-000-1111")
      expect(body).to include("Find Us:")
      expect(body).to include("1 Custom Way")
      expect(body).to include("About Custom Doug")
      expect(body).to include("Custom bio body.")
      expect(body).to include("Custom alt one")
      expect(body).to include("Custom alt two")
      expect(body).to include("Custom alt three")
    end

    it "does NOT render i18n shop_heading when published with custom value" do
      # Arrange
      create(:about_page_content, published: true, shop_heading: "CUSTOM SHOP")

      # Act
      get about_path

      # Assert
      expect(response.body).not_to include(I18n.t("pages.about.shop_heading"))
    end
  end

  describe "tel: link derivation (AT4, R4, E3)" do
    it "strips formatting punctuation for href but keeps visible text unmodified" do
      # Arrange
      create(:about_page_content, published: true, shop_phone_number: "(208) 555-1234")

      # Act
      get about_path

      # Assert
      expect(response.body).to include('href="tel:2085551234"')
      expect(response.body).to include("(208) 555-1234")
    end
  end

  describe "bio body whitespace-pre-line (AT6, AT7, R5)" do
    it "bio body <p> carries whitespace-pre-line when published with DB value (AT6)" do
      # Arrange
      create(:about_page_content, published: true, bio_body: "First.\nSecond.")

      # Act
      get about_path

      # Assert
      expect(response.body).to include("whitespace-pre-line")
      expect(response.body).to include("First.")
    end

    it "bio body <p> carries whitespace-pre-line even on i18n fallback path (AT7, AC-6)" do
      # Arrange — no AboutPageContent row

      # Act
      get about_path

      # Assert
      expect(response.body).to include("whitespace-pre-line")
    end
  end

  describe "slideshow alt mapping (AT8, R20)" do
    it "maps the 3 img alt attributes to slideshow_alt_1/2/3 in document order" do
      # Arrange
      create(
        :about_page_content,
        published: true,
        slideshow_alt_1: "First custom alt",
        slideshow_alt_2: "Second custom alt",
        slideshow_alt_3: "Third custom alt"
      )

      # Act
      get about_path

      # Assert
      body = response.body
      expect(body.index("First custom alt")).to be < body.index("Second custom alt")
      expect(body.index("Second custom alt")).to be < body.index("Third custom alt")
    end
  end

  describe "slideshow image fallback (SPEC-009 AT1-AT4, AT16)" do
    it "renders all 3 static fallback paths when no AboutPageContent row exists (AT1, R4, R6, E1, E9)" do
      # Arrange — table empty by default

      # Act
      get about_path

      # Assert
      document = Nokogiri::HTML(response.body)
      slideshow_srcs = document.css("section.slideshow img").map { |img| img["src"] }
      expect(slideshow_srcs[0]).to include("gallery/m45a2920")
      expect(slideshow_srcs[1]).to include("gallery/m45a2927")
      expect(slideshow_srcs[2]).to include("gallery/m45a2928")
    end

    it "renders slot 1 as an Active Storage representation while slots 2 and 3 stay static (AT2, R1, R3, R4, E3)" do
      # Arrange
      create(:about_page_content, :published, :with_slideshow_image_1)

      # Act
      get about_path

      # Assert
      document = Nokogiri::HTML(response.body)
      slideshow_srcs = document.css("section.slideshow img").map { |img| img["src"] }
      expect(slideshow_srcs[0]).to match(%r{/rails/active_storage/representations/})
      expect(slideshow_srcs[1]).to include("gallery/m45a2927")
      expect(slideshow_srcs[2]).to include("gallery/m45a2928")
    end

    it "renders all 3 static fallback paths when published is false despite an attached image (AT3, R4, R5, E2)" do
      # Arrange
      about_page_content = create(:about_page_content, :with_slideshow_image_1, published: false)

      # Act
      get about_path

      # Assert
      expect(about_page_content.slideshow_image_1).to be_attached
      document = Nokogiri::HTML(response.body)
      slideshow_srcs = document.css("section.slideshow img").map { |img| img["src"] }
      expect(slideshow_srcs[0]).to include("gallery/m45a2920")
      expect(slideshow_srcs[1]).to include("gallery/m45a2927")
      expect(slideshow_srcs[2]).to include("gallery/m45a2928")
    end

    it "renders all 3 slots as Active Storage representations in document order when all 3 are attached (AT4, R3, R4)" do
      # Arrange
      create(:about_page_content, :published, :with_slideshow_image_1, :with_slideshow_image_2, :with_slideshow_image_3)

      # Act
      get about_path

      # Assert
      document = Nokogiri::HTML(response.body)
      slideshow_srcs = document.css("section.slideshow img").map { |img| img["src"] }
      expect(slideshow_srcs.count).to eq(3)
      expect(slideshow_srcs).to all(match(%r{/rails/active_storage/representations/}))
    end

    it "renders custom alt text for slot 1 regardless of whether the image is uploaded or static (AT16, R11)" do
      # Arrange
      create(:about_page_content, :published, :with_slideshow_image_1, slideshow_alt_1: "Custom alt text")

      # Act
      get about_path

      # Assert
      document = Nokogiri::HTML(response.body)
      slideshow_alts = document.css("section.slideshow img").map { |img| img["alt"] }
      expect(slideshow_alts[0]).to eq("Custom alt text")
    end
  end

  describe "non-editable copy always renders from i18n (R1)" do
    it "always renders the contact heading from i18n regardless of publish state" do
      # Arrange
      create(:about_page_content, published: true)

      # Act
      get about_path

      # Assert
      expect(response.body).to include(I18n.t("pages.about.contact_heading"))
    end
  end
end
