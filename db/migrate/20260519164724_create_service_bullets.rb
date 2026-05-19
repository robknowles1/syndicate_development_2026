class CreateServiceBullets < ActiveRecord::Migration[8.1]
  def change
    create_table :service_bullets do |t|
      t.references :service_section, null: false, foreign_key: true, index: false
      t.string :body, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :service_bullets, [ :service_section_id, :position ]
  end
end
