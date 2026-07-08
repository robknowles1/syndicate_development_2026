class CreateHomePageContents < ActiveRecord::Migration[8.1]
  def change
    create_table :home_page_contents do |t|
      t.string  :hero_tagline,        null: false
      t.string  :mission_heading,     null: false
      t.string  :mission_subheading,  null: false
      t.text    :mission_body,        null: false
      t.boolean :published,           null: false, default: false

      t.timestamps
    end
  end
end
