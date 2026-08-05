class CreateBusinessHours < ActiveRecord::Migration[8.1]
  def change
    create_table :business_hours do |t|
      t.time :monday_opens_at
      t.time :monday_closes_at
      t.time :tuesday_opens_at
      t.time :tuesday_closes_at
      t.time :wednesday_opens_at
      t.time :wednesday_closes_at
      t.time :thursday_opens_at
      t.time :thursday_closes_at
      t.time :friday_opens_at
      t.time :friday_closes_at
      t.time :saturday_opens_at
      t.time :saturday_closes_at
      t.time :sunday_opens_at
      t.time :sunday_closes_at

      t.timestamps
    end
  end
end
