class AddPositionToServiceSections < ActiveRecord::Migration[8.1]
  def up
    add_column :service_sections, :position, :integer
    ServiceSection.order(:id).each_with_index do |section, i|
      section.update_column(:position, i)
    end
    change_column_null :service_sections, :position, false, 0
  end

  def down
    remove_column :service_sections, :position
  end
end
