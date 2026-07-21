class CreateGalleryPhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :gallery_photos do |t|
      t.integer :position, null: false, default: 0
      t.timestamps
    end
  end
end
