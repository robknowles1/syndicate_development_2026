class CreateSocialMediaLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :social_media_links do |t|
      t.string :platform, null: false
      t.string :url, null: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :social_media_links, :platform, unique: true
  end
end
