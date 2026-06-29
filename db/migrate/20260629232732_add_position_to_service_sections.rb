class AddPositionToServiceSections < ActiveRecord::Migration[8.1]
  def change
    add_column :service_sections, :position, :integer, null: false, default: 0
  end
end
