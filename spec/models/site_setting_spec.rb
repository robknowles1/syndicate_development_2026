require "rails_helper"

RSpec.describe SiteSetting, type: :model do
  describe ".get" do
    it "returns the string value for a known key" do
      SiteSetting.create!(key: "test_key", value: "test_value")
      expect(SiteSetting.get("test_key")).to eq("test_value")
    end

    it "returns nil for an unknown key" do
      expect(SiteSetting.get("nonexistent_key")).to be_nil
    end
  end

  describe ".set" do
    it "creates a new record when the key does not exist" do
      expect {
        SiteSetting.set("new_key", "new_value")
      }.to change(SiteSetting, :count).by(1)
      expect(SiteSetting.get("new_key")).to eq("new_value")
    end

    it "updates the value when the key already exists" do
      SiteSetting.create!(key: "existing_key", value: "old_value")
      expect {
        SiteSetting.set("existing_key", "updated_value")
      }.not_to change(SiteSetting, :count)
      expect(SiteSetting.get("existing_key")).to eq("updated_value")
    end
  end

  describe ".enabled?" do
    it "returns true when the value is \"true\"" do
      SiteSetting.create!(key: "feature_flag", value: "true")
      expect(SiteSetting.enabled?("feature_flag")).to be true
    end

    it "returns false when the value is \"false\"" do
      SiteSetting.create!(key: "feature_flag", value: "false")
      expect(SiteSetting.enabled?("feature_flag")).to be false
    end

    it "returns false for an unknown key" do
      expect(SiteSetting.enabled?("unknown_flag")).to be false
    end
  end
end
