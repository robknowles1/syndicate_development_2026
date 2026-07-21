namespace :gallery_photos do
  desc "One-time backfill of app/assets/images/gallery/*.jpg into GalleryPhoto records"
  task backfill: :environment do
    paths = Dir.glob(Rails.root.join("app/assets/images/gallery/*.jpg")).sort
    paths.each_with_index do |path, index|
      filename = File.basename(path)
      next if GalleryPhoto.joins(image_attachment: :blob)
                           .where(active_storage_blobs: { filename: filename })
                           .exists?

      photo = GalleryPhoto.new(position: index)
      photo.image.attach(io: File.open(path), filename: filename)
      photo.save!
    end
  end
end
