require "rails_helper"

RSpec.describe BusinessHours, type: :model do
  describe "the business_hours table" do
    it "carries a nullable opens/closes time pair for each of the seven days (AT13, AC-15)" do
      # Arrange
      expected_day_columns = described_class::DAYS.flat_map { |day| [ "#{day}_opens_at", "#{day}_closes_at" ] }

      # Act
      columns = described_class.columns.index_by(&:name)

      # Assert
      expect(columns.keys).to contain_exactly(*expected_day_columns, "id", "created_at", "updated_at")
      expect(expected_day_columns.map { |name| columns[name].type }).to all(eq(:time))
      expect(expected_day_columns.map { |name| columns[name].null }).to all(be(true))
    end
  end

  describe "DAYS" do
    it "lists the seven days in Monday-first order (R12)" do
      expect(described_class::DAYS).to eq(
        %w[monday tuesday wednesday thursday friday saturday sunday]
      )
    end
  end

  describe "validations" do
    it "is valid when every column is blank (AT16, AC-18)" do
      expect(described_class.new).to be_valid
    end

    it "is invalid when a day opens but never closes (AT14, AC-16, E5)" do
      # Arrange
      hours = described_class.new(monday_opens_at: "08:00")

      # Act
      valid = hours.valid?

      # Assert
      expect(valid).to be(false)
      expect(hours.errors[:monday_opens_at]).to be_present
    end

    it "is invalid when a day closes but never opens (R14, E5)" do
      # Arrange
      hours = described_class.new(saturday_closes_at: "17:00")

      # Act
      valid = hours.valid?

      # Assert
      expect(valid).to be(false)
      expect(hours.errors[:saturday_closes_at]).to be_present
    end

    it "is invalid when a day closes before it opens (AT15, AC-17, E9)" do
      # Arrange
      hours = described_class.new(tuesday_opens_at: "17:00", tuesday_closes_at: "08:00")

      # Act
      valid = hours.valid?

      # Assert
      expect(valid).to be(false)
      expect(hours.errors[:tuesday_closes_at]).to be_present
    end

    it "is invalid when a day closes at the same time it opens (R14, E9)" do
      # Arrange
      hours = described_class.new(wednesday_opens_at: "09:00", wednesday_closes_at: "09:00")

      # Act
      valid = hours.valid?

      # Assert
      expect(valid).to be(false)
      expect(hours.errors[:wednesday_closes_at]).to be_present
    end

    it "is valid when every day carries a complete, forward-running span (R13, R14)" do
      # Arrange
      complete_week = described_class::DAYS.to_h { |day| [ day, [ "08:00", "17:00" ] ] }
      attributes = complete_week.flat_map { |day, (opens, closes)|
        [ [ "#{day}_opens_at", opens ], [ "#{day}_closes_at", closes ] ]
      }.to_h

      # Act
      hours = described_class.new(attributes)

      # Assert
      expect(hours).to be_valid
    end

    it "reports an error for every half-filled day rather than only the first (R14)" do
      # Arrange
      hours = described_class.new(monday_opens_at: "08:00", friday_closes_at: "17:00")

      # Act
      hours.valid?

      # Assert
      expect(hours.errors.attribute_names).to contain_exactly(:monday_opens_at, :friday_closes_at)
    end
  end

  describe "#hours_on?" do
    it "is true only when both of the day's times are present (R13)" do
      # Arrange
      hours = described_class.new(
        monday_opens_at: "08:00", monday_closes_at: "17:00",
        tuesday_opens_at: "08:00"
      )

      # Act
      set_days = described_class::DAYS.select { |day| hours.hours_on?(day) }

      # Assert
      expect(set_days).to eq([ "monday" ])
    end
  end

  describe "#days_with_hours" do
    it "returns only the days with both times, in DAYS order (R13, R19, E7)" do
      # Arrange
      hours = described_class.new(
        friday_opens_at: "10:00", friday_closes_at: "16:00",
        monday_opens_at: "08:00", monday_closes_at: "17:00",
        wednesday_opens_at: "09:00", wednesday_closes_at: "15:00"
      )

      # Act
      days = hours.days_with_hours

      # Assert
      expect(days).to eq(%w[monday wednesday friday])
    end

    it "returns an empty list when every column is blank (R19, E6)" do
      expect(described_class.new.days_with_hours).to be_empty
    end
  end

  describe "#opening_hours_specification" do
    it "returns one HH:MM entry per set day, in DAYS order (AT21, R16, AC-24, E7)" do
      # Arrange
      hours = described_class.new(
        wednesday_opens_at: "09:30", wednesday_closes_at: "15:05",
        monday_opens_at: "08:00", monday_closes_at: "17:00"
      )

      # Act
      specification = hours.opening_hours_specification

      # Assert
      expect(specification).to eq([
        {
          "@type" => "OpeningHoursSpecification",
          "dayOfWeek" => "https://schema.org/Monday",
          "opens" => "08:00",
          "closes" => "17:00"
        },
        {
          "@type" => "OpeningHoursSpecification",
          "dayOfWeek" => "https://schema.org/Wednesday",
          "opens" => "09:30",
          "closes" => "15:05"
        }
      ])
    end

    it "returns nil when no day carries both times (AT21, R16, AC-25, E6)" do
      expect(described_class.new.opening_hours_specification).to be_nil
    end

    it "skips a half-filled day rather than emitting a partial entry (R13, R16)" do
      # Arrange
      hours = described_class.new(
        sunday_opens_at: "10:00",
        saturday_opens_at: "09:00", saturday_closes_at: "12:00"
      )

      # Act
      specification = hours.opening_hours_specification

      # Assert
      expect(specification.map { |entry| entry["dayOfWeek"] }).to eq([ "https://schema.org/Saturday" ])
    end
  end
end
