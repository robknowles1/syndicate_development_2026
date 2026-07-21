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

  describe "config/importmap.rb" do
    it "pins sortablejs (AT33, R23, AC-34)" do
      # Arrange
      source = File.read(Rails.root.join("config/importmap.rb"))

      # Assert
      expect(source).to match(/pin\s+"sortablejs"/)
    end
  end

  describe "app/javascript/controllers/gallery_sort_controller.js and controllers/index.js" do
    it "exists and needs no manual registration entry (AT34, R24, AC-35)" do
      # Arrange
      controller_path = Rails.root.join("app/javascript/controllers/gallery_sort_controller.js")
      index_source = File.read(Rails.root.join("app/javascript/controllers/index.js"))

      # Assert
      expect(File.exist?(controller_path)).to be true
      expect(index_source).to include("eagerLoadControllersFrom")
      expect(index_source).not_to include("gallery_sort_controller")
    end
  end

  describe "gallery_sort_controller.js onEnd handler" do
    it "returns before issuing a fetch request when newIndex equals oldIndex (AT36, R25, AC-37, E5)" do
      # Arrange
      source = File.read(Rails.root.join("app/javascript/controllers/gallery_sort_controller.js"))

      # Act
      guard_index = source.index("event.newIndex === event.oldIndex")
      fetch_index = source.index("fetch(")

      # Assert
      expect(guard_index).not_to be_nil
      expect(fetch_index).not_to be_nil
      expect(guard_index).to be < fetch_index
    end

    it "sets an X-CSRF-Token header sourced from the csrf-token meta tag (AT37, R26, AC-38)" do
      # Arrange
      source = File.read(Rails.root.join("app/javascript/controllers/gallery_sort_controller.js"))

      # Assert
      expect(source).to include("X-CSRF-Token")
      expect(source).to include(%(document.querySelector('meta[name="csrf-token"]').content))
    end
  end
end
