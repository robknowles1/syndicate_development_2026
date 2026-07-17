class CreateAboutPageContents < ActiveRecord::Migration[8.1]
  def change
    create_table :about_page_contents do |t|
      t.string  :shop_heading,       null: false
      t.string  :shop_phone_label,   null: false
      t.string  :shop_phone_number,  null: false
      t.string  :shop_address_label, null: false
      t.string  :shop_address,       null: false
      t.string  :bio_heading,        null: false
      t.text    :bio_body,           null: false
      t.string  :slideshow_alt_1,    null: false
      t.string  :slideshow_alt_2,    null: false
      t.string  :slideshow_alt_3,    null: false
      t.boolean :published,          null: false, default: false

      t.timestamps
    end
  end
end
