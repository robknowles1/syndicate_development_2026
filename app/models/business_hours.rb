class BusinessHours < ApplicationRecord
  DAYS = %w[monday tuesday wednesday thursday friday saturday sunday].freeze

  validate :each_day_is_whole_and_forward_running

  private

  def each_day_is_whole_and_forward_running
    DAYS.each do |day|
      opens_at = public_send("#{day}_opens_at")
      closes_at = public_send("#{day}_closes_at")

      if opens_at.present? && closes_at.blank?
        errors.add(:"#{day}_opens_at", :missing_closing_time)
      elsif closes_at.present? && opens_at.blank?
        errors.add(:"#{day}_closes_at", :missing_opening_time)
      elsif opens_at.present? && closes_at <= opens_at
        errors.add(:"#{day}_closes_at", :closes_before_opens)
      end
    end
  end
end
