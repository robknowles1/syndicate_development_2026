require "rails_helper"

RSpec.describe StructuredDataHelper, type: :helper do
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
