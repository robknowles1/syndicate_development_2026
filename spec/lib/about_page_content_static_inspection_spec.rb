require "rails_helper"

RSpec.describe "SPEC-009 about page content static source inspection" do
  describe "app/views/admin/about_page_contents/show.html.erb and Admin::AboutPageContentsController source" do
    it "contains no hardcoded English string literals outside of t()/I18n.t() calls (AT13, AC-13)" do
      # Arrange
      view_file = Rails.root.join("app/views/admin/about_page_contents/show.html.erb")
      controller_file = Rails.root.join("app/controllers/admin/about_page_contents_controller.rb")

      # Act
      static_html = File.read(view_file).gsub(/<%.*?%>/m, "")
      view_text_nodes = static_html.scan(/>([^<>]+)</).flatten.map(&:strip).reject(&:empty?)
      controller_source = File.read(controller_file).gsub(/I18n\.t\([^)]*\)/, "")

      # Assert
      suspicious_view_text = view_text_nodes.select { |text| text.match?(/[A-Za-z]{2,} [A-Za-z]{2,}/) }
      expect(suspicious_view_text).to be_empty
      expect(controller_source).not_to match(/["'][A-Za-z]+ [A-Za-z]+/)
    end
  end
end
