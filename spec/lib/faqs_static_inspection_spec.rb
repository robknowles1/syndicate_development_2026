require "rails_helper"

RSpec.describe "SPEC-012 FAQ admin source inspection" do
  describe "app/views/admin/faqs/ and Admin::FaqsController source" do
    it "contains no hardcoded English string literals outside of t()/I18n.t() calls (AT48, AC-13)" do
      # Arrange
      view_files = Rails.root.glob("app/views/admin/faqs/*.erb")
      controller_file = Rails.root.join("app/controllers/admin/faqs_controller.rb")

      # Act
      view_text_nodes = view_files.flat_map { |file|
        static_html = File.read(file).gsub(/<%.*?%>/m, "")
        static_html.scan(/>([^<>]+)</).flatten.map(&:strip).reject(&:empty?)
      }
      controller_source = File.read(controller_file).gsub(/I18n\.t\([^)]*\)/, "")

      # Assert
      expect(view_files).not_to be_empty
      expect(view_text_nodes.select { |text| text.match?(/[A-Za-z]{2,} [A-Za-z]{2,}/) }).to be_empty
      expect(controller_source).not_to match(/["'][A-Za-z]+ [A-Za-z]+/)
    end
  end
end
