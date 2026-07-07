class BackfillIconKeysToTabler < ActiveRecord::Migration[8.1]
  HEROICON_TO_TABLER = {
    "wrench"                  => "tool",
    "wrench-screwdriver"      => "tools",
    "bolt"                    => "bolt",
    "fire"                    => "flame",
    "beaker"                  => "flask",
    "adjustments-horizontal"  => "adjustments-horizontal",
    "adjustments-vertical"    => "adjustments",
    "cpu-chip"                => "cpu",
    "chart-bar"               => "chart-bar",
    "cog-6-tooth"             => "settings",
    "cog-8-tooth"             => "settings-2",
    "cube"                    => "cube",
    "sparkles"                => "sparkles",
    "trophy"                  => "trophy"
  }.freeze

  # The 4 new Tabler-only keys that have no Heroicon predecessor —
  # used in the down block guard to detect unrestorable rows.
  NEW_ONLY_KEYS = %w[engine car-suspension motorbike helmet].freeze

  def change
    reversible do |dir|
      dir.up do
        ServiceSection.reset_column_information

        HEROICON_TO_TABLER.each do |old_key, new_key|
          ServiceSection.where(icon_key: old_key).update_all(icon_key: new_key)
        end

        # After all remappings, any row still outside the new ICON_KEYS is an unknown
        # custom key with no migration target — fail loudly rather than silently corrupt.
        new_icon_keys = HEROICON_TO_TABLER.values + NEW_ONLY_KEYS
        unmapped = ServiceSection.where.not(icon_key: new_icon_keys).pluck(:icon_key).uniq
        if unmapped.any?
          raise StandardError, "BackfillIconKeysToTabler: found ServiceSection rows with unmapped " \
            "icon_key values after migration: #{unmapped.inspect}. " \
            "Add these keys to HEROICON_TO_TABLER or clean the data before migrating."
        end
      end

      dir.down do
        ServiceSection.reset_column_information

        # Guard: rows with any of the 4 new-only keys have no Heroicon equivalent.
        # Proceeding would leave them with stale Tabler keys once the old ICON_KEYS
        # (14 Heroicon entries) is restored — fail before touching any row.
        blocking = ServiceSection.where(icon_key: NEW_ONLY_KEYS).pluck(:icon_key).uniq
        if blocking.any?
          raise StandardError, "BackfillIconKeysToTabler (down): cannot reverse migration because " \
            "ServiceSection rows exist with icon_key values #{blocking.inspect} — these Tabler-only " \
            "keys have no Heroicon equivalent. Delete or reassign these sections before rolling back."
        end

        # Reverse the full 14-key mapping for every row (not only the seeded rows).
        HEROICON_TO_TABLER.each do |old_key, new_key|
          ServiceSection.where(icon_key: new_key).update_all(icon_key: old_key)
        end
      end
    end
  end
end
