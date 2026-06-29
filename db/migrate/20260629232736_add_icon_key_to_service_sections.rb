class AddIconKeyToServiceSections < ActiveRecord::Migration[8.1]
  def change
    reversible do |dir|
      dir.up do
        # Step 1: add the column as nullable so PostgreSQL accepts it on existing rows
        add_column :service_sections, :icon_key, :string

        # Step 2: backfill existing rows by slug
        ServiceSection.reset_column_information
        {
          "precision_engines"        => "cog-6-tooth",
          "custom_suspension"        => "adjustments-horizontal",
          "ecu_tuning"               => "cpu-chip"
        }.each do |slug, key|
          ServiceSection.where(slug: slug).update_all(icon_key: key)
        end

        # Step 3: add NOT NULL constraint now that all rows have a value
        change_column_null :service_sections, :icon_key, false
      end
    end
  end
end
