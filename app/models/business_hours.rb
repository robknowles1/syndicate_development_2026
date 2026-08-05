class BusinessHours < ApplicationRecord
  DAYS = %w[monday tuesday wednesday thursday friday saturday sunday].freeze

  validate :each_day_is_whole_and_forward_running

  def opens_at_on(day)
    public_send("#{day}_opens_at")
  end

  def closes_at_on(day)
    public_send("#{day}_closes_at")
  end

  def hours_on?(day)
    opens_at_on(day).present? && closes_at_on(day).present?
  end

  def days_with_hours
    DAYS.select { |day| hours_on?(day) }
  end

  def opening_hours_specification
    days_with_hours.map { |day|
      {
        "@type" => "OpeningHoursSpecification",
        "dayOfWeek" => "https://schema.org/#{day.capitalize}",
        "opens" => opens_at_on(day).strftime("%H:%M"),
        "closes" => closes_at_on(day).strftime("%H:%M")
      }
    }.presence
  end

  private

  def each_day_is_whole_and_forward_running
    DAYS.each do |day|
      opens_at = opens_at_on(day)
      closes_at = closes_at_on(day)

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
