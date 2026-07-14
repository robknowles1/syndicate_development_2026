require "rails_helper"

RSpec.describe "SPEC-008 gallery photo static source inspection" do
  describe "app/views/admin/gallery_photos/ and Admin::GalleryPhotosController source" do
    it "contains no hardcoded English string literals outside of t()/I18n.t() calls (AT25, AC-26)" do
      # Arrange
      view_files = Dir.glob(Rails.root.join("app/views/admin/gallery_photos/**/*.erb"))
      controller_file = Rails.root.join("app/controllers/admin/gallery_photos_controller.rb")

      # Act
      view_text_nodes = view_files.flat_map do |path|
        static_html = File.read(path).gsub(/<%.*?%>/m, "")
        static_html.scan(/>([^<>]+)</).flatten.map(&:strip).reject(&:empty?)
      end
      controller_source = File.read(controller_file).gsub(/I18n\.t\([^)]*\)/, "")

      # Assert
      suspicious_view_text = view_text_nodes.select { |text| text.match?(/[A-Za-z]{2,} [A-Za-z]{2,}/) }
      expect(suspicious_view_text).to be_empty
      expect(controller_source).not_to match(/["'][A-Za-z]+ [A-Za-z]+/)
    end
  end

  describe "db/seeds.rb, db/migrate/, and .github/workflows/ci.yml" do
    it "never invokes gallery_photos:backfill automatically (AT31, R22, AC-32)" do
      # Arrange
      seeds_source = File.read(Rails.root.join("db/seeds.rb"))
      migration_sources = Dir.glob(Rails.root.join("db/migrate/*.rb")).map { |path| File.read(path) }
      ci_workflow_path = Rails.root.join(".github/workflows/ci.yml")
      ci_source = File.exist?(ci_workflow_path) ? File.read(ci_workflow_path) : ""

      # Act & Assert
      expect(seeds_source).not_to include("gallery_photos:backfill")
      expect(migration_sources.join).not_to include("gallery_photos:backfill")
      expect(ci_source).not_to include("gallery_photos:backfill")
    end
  end
end
