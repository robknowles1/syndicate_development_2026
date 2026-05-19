class CreateServiceSections < ActiveRecord::Migration[8.1]
  def change
    create_table :service_sections do |t|
      t.string :slug, null: false
      t.string :heading, null: false

      t.timestamps
    end

    add_index :service_sections, :slug, unique: true
  end
end
