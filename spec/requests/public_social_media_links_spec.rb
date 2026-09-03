require "rails_helper"

RSpec.describe "Public social media links", type: :request do
  def social_links_at(response_body, location)
    Nokogiri::HTML(response_body).css("[data-social-media-links='#{location}'] a")
  end

  def wrapper_at(response_body, location)
    Nokogiri::HTML(response_body).css("[data-social-media-links='#{location}']")
  end

  def create_instagram_and_facebook
    create(:social_media_link, platform: "instagram", url: "https://instagram.com/syndicate", position: 0)
    create(:social_media_link, platform: "facebook", url: "https://facebook.com/syndicate", position: 1)
  end

  describe "the site footer" do
    context "with two active links" do
      it "renders one icon-only link each, in position order (AT21, R12, R15, R16, AC-21, E4)" do
        # Arrange
        create_instagram_and_facebook

        # Act
        get root_path
        links = social_links_at(response.body, "footer")

        # Assert
        expect(links.map { |a| a["href"] })
          .to eq([ "https://instagram.com/syndicate", "https://facebook.com/syndicate" ])
        expect(links.map { |a| a["aria-label"] }).to eq([ "Instagram", "Facebook" ])
        expect(links.map { |a| a["rel"] }).to all(eq("noopener noreferrer"))
        expect(links.map { |a| a["target"] }).to all(eq("_blank"))
      end

      it "gives every icon aria-hidden and renders no visible platform text (AT21, R15, AC-21)" do
        # Arrange
        create_instagram_and_facebook

        # Act
        get root_path
        links = social_links_at(response.body, "footer")

        # Assert
        expect(links.map { |a| a.at_css("svg")["aria-hidden"] }).to all(eq("true"))
        expect(links.map { |a| a.text.strip }).to all(be_empty)
      end
    end

    context "with a single active link" do
      it "renders exactly one icon (E3)" do
        # Arrange
        create(:social_media_link, platform: "youtube", url: "https://youtube.com/@syndicate", position: 0)

        # Act
        get root_path

        # Assert
        expect(social_links_at(response.body, "footer").size).to eq(1)
      end
    end

    context "with an inactive link mixed among active ones" do
      it "excludes the inactive link and keeps the others in order (E5)" do
        # Arrange
        create(:social_media_link, platform: "instagram", url: "https://instagram.com/a", position: 0)
        create(:social_media_link, platform: "youtube", url: "https://youtube.com/b", position: 1, active: false)
        create(:social_media_link, platform: "facebook", url: "https://facebook.com/c", position: 2)

        # Act
        get root_path

        # Assert
        expect(social_links_at(response.body, "footer").map { |a| a["aria-label"] })
          .to eq([ "Instagram", "Facebook" ])
      end
    end

    context "without any links at all" do
      it "renders no wrapper element in the footer (AT22, R14, AC-22, E1)" do
        # Act
        get root_path

        # Assert
        expect(wrapper_at(response.body, "footer")).to be_empty
      end
    end

    context "with links that are all inactive" do
      it "renders no wrapper element in the footer (AT22, R14, AC-22, E2)" do
        # Arrange
        create(:social_media_link, platform: "instagram", position: 0, active: false)
        create(:social_media_link, platform: "facebook", position: 1, active: false)

        # Act
        get root_path

        # Assert
        expect(wrapper_at(response.body, "footer")).to be_empty
      end
    end

    context "with two active links, on every public page" do
      it "renders the footer row without any controller having to assign it (R13)" do
        # Arrange
        create_instagram_and_facebook
        SiteSetting.set("services_page_published", "true")

        # Act / Assert
        [ root_path, about_path, gallery_path, services_path ].each do |path|
          get path

          expect(social_links_at(response.body, "footer").map { |a| a["aria-label"] })
            .to eq([ "Instagram", "Facebook" ]), "expected the footer row on #{path}"
        end
      end
    end
  end

  describe "the home page closing CTA band" do
    context "with two active links" do
      it "renders the same icon-only links below the contact link (AT23, R13, R16, AC-23)" do
        # Arrange
        create_instagram_and_facebook

        # Act
        get root_path
        links = social_links_at(response.body, "home-cta")

        # Assert
        expect(links.map { |a| a["href"] })
          .to eq([ "https://instagram.com/syndicate", "https://facebook.com/syndicate" ])
        expect(links.map { |a| a["aria-label"] }).to eq([ "Instagram", "Facebook" ])
        expect(links.map { |a| a.at_css("svg")["aria-hidden"] }).to all(eq("true"))
        expect(links.map { |a| a.text.strip }).to all(be_empty)
      end

      it "positions the row after the contact link (AT23, R16, AC-23)" do
        # Arrange
        create_instagram_and_facebook

        # Act
        get root_path

        # Assert
        expect(response.body.index(I18n.t("pages.home.cta_contact")))
          .to be < response.body.index("data-social-media-links=\"home-cta\"")
      end
    end

    context "without any links at all" do
      it "renders no wrapper element in the CTA band (AT24, R14, AC-24, E1)" do
        # Act
        get root_path

        # Assert
        expect(wrapper_at(response.body, "home-cta")).to be_empty
      end
    end
  end

  describe "the About page shop-info block" do
    context "with two active links" do
      it "renders the same icon-only links below the phone and address (AT25, R13, R16, AC-25)" do
        # Arrange
        create_instagram_and_facebook

        # Act
        get about_path
        links = social_links_at(response.body, "about")

        # Assert
        expect(links.map { |a| a["href"] })
          .to eq([ "https://instagram.com/syndicate", "https://facebook.com/syndicate" ])
        expect(links.map { |a| a["aria-label"] }).to eq([ "Instagram", "Facebook" ])
        expect(links.map { |a| a.at_css("svg")["aria-hidden"] }).to all(eq("true"))
        expect(links.map { |a| a.text.strip }).to all(be_empty)
      end

      it "positions the row after the address link (AT25, R16, AC-25)" do
        # Arrange
        create_instagram_and_facebook

        # Act
        get about_path

        # Assert
        expect(response.body.index(I18n.t("pages.about.shop_address")))
          .to be < response.body.index("data-social-media-links=\"about\"")
      end
    end

    context "without any links at all" do
      it "renders no wrapper element on the About page (AT26, R14, AC-26, E1)" do
        # Act
        get about_path

        # Assert
        expect(wrapper_at(response.body, "about")).to be_empty
      end
    end
  end

  describe "a link that is deleted after being rendered" do
    context "with one of two links removed" do
      it "stops appearing on the very next request (E9)" do
        # Arrange
        create_instagram_and_facebook
        get root_path
        expect(social_links_at(response.body, "footer").size).to eq(2)

        # Act
        SocialMediaLink.find_by(platform: "facebook").destroy
        get root_path

        # Assert
        expect(social_links_at(response.body, "footer").map { |a| a["aria-label"] }).to eq([ "Instagram" ])
      end
    end
  end

  describe "ordering across all four locations" do
    context "with three active links in a non-alphabetical position order" do
      it "presents the identical relative order everywhere (AT29, R18, AC-29)" do
        # Arrange
        create(:social_media_link, platform: "youtube", url: "https://youtube.com/@c", position: 0)
        create(:social_media_link, platform: "instagram", url: "https://instagram.com/a", position: 1)
        create(:social_media_link, platform: "facebook", url: "https://facebook.com/b", position: 2)
        expected = [ "https://youtube.com/@c", "https://instagram.com/a", "https://facebook.com/b" ]

        # Act
        get root_path
        home_footer = social_links_at(response.body, "footer").map { |a| a["href"] }
        home_cta = social_links_at(response.body, "home-cta").map { |a| a["href"] }
        same_as = JSON.parse(Nokogiri::HTML(response.body).at_css("script[type='application/ld+json']").text)["sameAs"]

        get about_path
        about_block = social_links_at(response.body, "about").map { |a| a["href"] }

        # Assert
        expect(home_footer).to eq(expected)
        expect(home_cta).to eq(expected)
        expect(about_block).to eq(expected)
        expect(same_as).to eq(expected)
      end
    end
  end

  describe "the rendered tap targets" do
    context "with two active links" do
      it "pads each link beyond its icon and wraps rather than scrolling (R19, AC-31)" do
        # Arrange
        create_instagram_and_facebook

        # Act
        get root_path
        document = Nokogiri::HTML(response.body)

        # Assert
        %w[footer home-cta].each do |location|
          expect(document.at_css("[data-social-media-links='#{location}']")["class"]).to include("flex-wrap")
          document.css("[data-social-media-links='#{location}'] a").each do |link|
            expect(link["class"]).to include("p-2"), "expected padded tap area at #{location}"
          end
        end
      end
    end
  end
end
