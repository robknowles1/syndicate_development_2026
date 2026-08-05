require "rails_helper"

RSpec.describe "LocalBusiness structured data (SPEC-012 Part D)", type: :request do
  def json_ld_blocks(body)
    Nokogiri::HTML(body)
      .css("script[type='application/ld+json']")
      .map { |script| JSON.parse(script.text) }
  end

  def business_nodes(body)
    json_ld_blocks(body).select { |node| node["@type"] == "MotorcycleRepair" }
  end

  def business_node(body)
    business_nodes(body).first
  end

  def public_page_paths
    SiteSetting.set("services_page_published", "true")
    [ root_path, about_path, gallery_path, services_path ]
  end

  describe "presence and identity" do
    it "renders exactly one MotorcycleRepair node on every public page (AT25, R26, R27, AC-30)" do
      # Arrange
      paths = public_page_paths

      # Act
      node_counts = paths.map { |path|
        get path
        business_nodes(response.body).size
      }

      # Assert
      expect(node_counts).to eq([ 1, 1, 1, 1 ])
    end

    it "gives that node the same @id on every public page (AT25, R26, AC-30)" do
      # Arrange
      paths = public_page_paths

      # Act
      ids = paths.map { |path|
        get path
        business_node(response.body)["@id"]
      }

      # Assert
      expect(ids).to all(eq("#{root_url}#business"))
    end

    it "declares the schema.org context (R26)" do
      # Act
      get root_path

      # Assert
      expect(business_node(response.body)["@context"]).to eq("https://schema.org")
    end
  end

  describe "phone and street address (R28)" do
    it "reuses the i18n fallbacks the About page renders when no content row exists (AT25, AC-31, E12)" do
      # Act
      get root_path

      # Assert
      node = business_node(response.body)
      expect(node["telephone"]).to eq(I18n.t("pages.about.shop_phone_number"))
      expect(node["address"]["streetAddress"]).to eq(I18n.t("pages.about.shop_address"))
    end

    it "reuses the published About page values (AT25, AC-31)" do
      # Arrange
      create(:about_page_content, :published,
        shop_phone_number: "208-555-0100",
        shop_address: "42 Race Shop Row, Pocatello, ID, 83204")

      # Act
      get gallery_path

      # Assert
      node = business_node(response.body)
      expect(node["telephone"]).to eq("208-555-0100")
      expect(node["address"]["streetAddress"]).to eq("42 Race Shop Row, Pocatello, ID, 83204")
    end

    it "ignores unpublished About page edits, matching what the About page shows (AT25, AC-31, E12, E14)" do
      # Arrange
      create(:about_page_content, published: false,
        shop_phone_number: "208-555-0100",
        shop_address: "42 Race Shop Row, Pocatello, ID, 83204")

      # Act
      get root_path

      # Assert
      node = business_node(response.body)
      expect(node["telephone"]).to eq(I18n.t("pages.about.shop_phone_number"))
      expect(node["address"]["streetAddress"]).to eq(I18n.t("pages.about.shop_address"))
    end

    def about_page_content_query_count(path)
      queries = []
      subscription = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, payload|
        queries << payload[:sql] if payload[:sql].include?("about_page_contents")
      }
      get path
      ActiveSupport::Notifications.unsubscribe(subscription)
      queries.size
    end

    it "queries AboutPageContent once on the pages the schema is the only reader of (R28)" do
      # Arrange
      create(:about_page_content, :published)
      SiteSetting.set("services_page_published", "true")

      # Act
      counts = [ root_path, gallery_path, services_path ].map { |path|
        about_page_content_query_count(path)
      }

      # Assert
      expect(counts).to eq([ 1, 1, 1 ])
    end

    # /about reads the row a second time because PagesController#about loads its own
    # attachment-preloaded copy for the page body. Recorded rather than implied, so that
    # collapsing the two is a deliberate change to this number and not a silent one.
    it "queries AboutPageContent twice on /about, which loads its own copy (R28)" do
      # Arrange
      create(:about_page_content, :published)

      # Act
      count = about_page_content_query_count(about_path)

      # Assert
      expect(count).to eq(2)
    end
  end

  describe "fixed address, geo and service area" do
    it "renders the fixed postal address constants (AT26, R29, AC-32)" do
      # Act
      get root_path

      # Assert
      expect(business_node(response.body)["address"]).to include(
        "addressLocality" => "Pocatello",
        "addressRegion" => "ID",
        "postalCode" => "83204",
        "addressCountry" => "US"
      )
    end

    it "renders the fixed geo coordinates (AT26, R29, AC-32)" do
      # Act
      get root_path

      # Assert
      expect(business_node(response.body)["geo"]).to include(
        "latitude" => 42.8739291,
        "longitude" => -112.4668151
      )
    end

    it "renders the five fixed areaServed entries (AT27, R30, AC-33)" do
      # Act
      get root_path

      # Assert
      expect(business_node(response.body)["areaServed"]).to eq([
        { "@type" => "City", "name" => "Pocatello" },
        { "@type" => "City", "name" => "Idaho Falls" },
        { "@type" => "City", "name" => "Boise" },
        { "@type" => "State", "name" => "Idaho" },
        { "@type" => "State", "name" => "Utah" }
      ])
    end

    it "renders the business name, site URL and hero image (AT27, R31, AC-34)" do
      # Act
      get root_path

      # Assert
      node = business_node(response.body)
      expect(node["name"]).to eq("Syndicate Development")
      expect(node["url"]).to eq(root_url)
      expect(node["image"]).to start_with(root_url)
      expect(node["image"]).to match(%r{/assets/gallery/m45a2849[^/]*\.jpg\z})
    end
  end

  describe "opening hours (R17)" do
    it "lists only the days that carry both times (AT21, AC-24, E7)" do
      # Arrange
      BusinessHours.create!(
        monday_opens_at: "08:00", monday_closes_at: "17:00",
        wednesday_opens_at: "08:00", wednesday_closes_at: "17:00",
        friday_opens_at: "09:00", friday_closes_at: "16:30"
      )

      # Act
      get root_path

      # Assert
      expect(business_node(response.body)["openingHoursSpecification"]).to eq([
        { "@type" => "OpeningHoursSpecification", "dayOfWeek" => "https://schema.org/Monday", "opens" => "08:00", "closes" => "17:00" },
        { "@type" => "OpeningHoursSpecification", "dayOfWeek" => "https://schema.org/Wednesday", "opens" => "08:00", "closes" => "17:00" },
        { "@type" => "OpeningHoursSpecification", "dayOfWeek" => "https://schema.org/Friday", "opens" => "09:00", "closes" => "16:30" }
      ])
    end

    it "omits the key entirely when every day is blank (AT21, AC-25, E6)" do
      # Arrange
      BusinessHours.create!

      # Act
      get root_path

      # Assert
      expect(business_node(response.body)).not_to have_key("openingHoursSpecification")
    end

    it "omits the key entirely when no BusinessHours row exists (AT21, AC-25, E8)" do
      # Act
      get root_path

      # Assert
      expect(business_node(response.body)).not_to have_key("openingHoursSpecification")
    end
  end

  describe "script context escaping (R32)" do
    it "escapes a </script> sequence smuggled through the shop address (AT11, AC-11, E4)" do
      # Arrange
      create(:about_page_content, :published,
        shop_address: "1801 N. Arthur Ave. </script><script>alert(1)</script>")

      # Act
      get root_path

      # Assert
      expect(response.body).not_to include("<script>alert(1)</script>")
      expect(business_node(response.body)["address"]["streetAddress"])
        .to eq("1801 N. Arthur Ave. </script><script>alert(1)</script>")
    end
  end
end
