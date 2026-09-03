require "rails_helper"

RSpec.describe StructuredDataHelper, type: :helper do
  describe "#local_business_schema" do
    context "with two active links and one inactive link" do
      it "lists only the active urls, in position order (AT27, R17, R18, AC-27, E5)" do
        # Arrange
        create(:social_media_link, platform: "instagram", url: "https://instagram.com/syndicate", position: 0)
        create(:social_media_link, platform: "facebook", url: "https://facebook.com/syndicate", position: 1)
        create(:social_media_link, platform: "youtube", url: "https://youtube.com/@syndicate", position: 2, active: false)

        # Act
        schema = helper.local_business_schema

        # Assert
        expect(schema["sameAs"]).to eq([ "https://instagram.com/syndicate", "https://facebook.com/syndicate" ])
      end
    end

    context "without any links at all" do
      it "omits the sameAs key entirely rather than emitting an empty array (AT28, R17, AC-28, E1)" do
        # Act
        schema = helper.local_business_schema

        # Assert
        expect(schema.key?("sameAs")).to be(false)
      end
    end

    context "with links that are all inactive" do
      it "omits the sameAs key entirely (AT28, R17, AC-28, E2)" do
        # Arrange
        create(:social_media_link, platform: "instagram", position: 0, active: false)

        # Act
        schema = helper.local_business_schema

        # Assert
        expect(schema.key?("sameAs")).to be(false)
      end
    end

    context "with a single active link" do
      it "emits a one-element array (E3)" do
        # Arrange
        create(:social_media_link, platform: "x", url: "https://x.com/syndicate", position: 0)

        # Act
        schema = helper.local_business_schema

        # Assert
        expect(schema["sameAs"]).to eq([ "https://x.com/syndicate" ])
      end
    end
  end

  describe "#json_ld_script_tag" do
    it "neutralises < even when to_json does not escape it (AT11, R32, AC-11)" do
      # Arrange — a real hash would be escaped by to_json itself under
      # ActiveSupport.escape_html_entities_in_json, masking json_escape's removal.
      unescaped = double(:schema, to_json: %({"text":"</script><script>alert(1)</script>"}))

      # Act
      emitted = helper.json_ld_script_tag(unescaped)

      # Assert
      expect(emitted).not_to include("<script>alert(1)</script>")
      expect(emitted.scan(%r{</script}i).size).to eq(1)
    end

    it "emits JSON a parser accepts, not an HTML-escaped copy of it (R32)" do
      # Arrange
      schema = { "name" => %(Doug's "shop" & garage) }

      # Act
      emitted = helper.json_ld_script_tag(schema)

      # Assert
      expect(JSON.parse(Nokogiri::HTML(emitted).at_css("script").text))
        .to eq("name" => %(Doug's "shop" & garage))
    end
  end
end
