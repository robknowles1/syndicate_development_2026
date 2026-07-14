require "rails_helper"

RSpec.describe "gallery_photos:backfill", type: :task do
  describe "when app/assets/images/gallery/*.jpg contains N files and zero GalleryPhoto rows exist" do
    it "creates exactly N rows positioned in alphabetical glob order (AT28, AC-29, E7)" do
      # Arrange
      paths = Dir.glob(Rails.root.join("app/assets/images/gallery/*.jpg")).sort
      expected_filenames = paths.map { |path| File.basename(path) }
      Rake::Task["gallery_photos:backfill"].reenable

      # Act
      Rake::Task["gallery_photos:backfill"].invoke

      # Assert
      expect(GalleryPhoto.count).to eq(expected_filenames.count)
      actual_filenames = GalleryPhoto.order(:position)
                                      .joins(image_attachment: :blob)
                                      .pluck("active_storage_blobs.filename")
      expect(actual_filenames).to eq(expected_filenames)
    end
  end

  describe "when the backfill task has already run once" do
    it "does not create duplicate rows on a second run (AT29, AC-30, E8)" do
      # Arrange
      Rake::Task["gallery_photos:backfill"].reenable
      Rake::Task["gallery_photos:backfill"].invoke
      count_after_first_run = GalleryPhoto.count
      Rake::Task["gallery_photos:backfill"].reenable

      # Act
      Rake::Task["gallery_photos:backfill"].invoke

      # Assert
      expect(GalleryPhoto.count).to eq(count_after_first_run)
    end
  end

  describe "when the backfill has run for all but one file" do
    it "creates exactly one new row for the missing file and leaves existing rows untouched (AT30, AC-31, E8)" do
      # Arrange
      Rake::Task["gallery_photos:backfill"].reenable
      Rake::Task["gallery_photos:backfill"].invoke
      full_count = GalleryPhoto.count
      removed_photo = GalleryPhoto.order(:position).first
      removed_photo.image.purge
      removed_photo.destroy
      remaining_ids = GalleryPhoto.order(:position).pluck(:id)
      Rake::Task["gallery_photos:backfill"].reenable

      # Act
      Rake::Task["gallery_photos:backfill"].invoke

      # Assert
      expect(GalleryPhoto.count).to eq(full_count)
      expect(GalleryPhoto.order(:position).pluck(:id)).to include(*remaining_ids)
    end
  end
end
