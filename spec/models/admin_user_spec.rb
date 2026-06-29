require "rails_helper"

RSpec.describe AdminUser, type: :model do
  subject(:admin_user) { build(:admin_user) }

  describe "validations" do
    it "is valid with email and password" do
      expect(admin_user).to be_valid
    end

    it { is_expected.to validate_presence_of(:email) }

    it "is invalid without a password" do
      user = build(:admin_user, password: nil, password_confirmation: nil)
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it "validates uniqueness of email (case insensitive)" do
      create(:admin_user, email: "admin@example.com")
      duplicate = build(:admin_user, email: "ADMIN@EXAMPLE.COM")
      expect(duplicate).not_to be_valid
    end

    it "validates email format" do
      bad_email = build(:admin_user, email: "not-an-email")
      expect(bad_email).not_to be_valid
      expect(bad_email.errors[:email]).to be_present
    end
  end

  describe "authentication" do
    let!(:saved_user) { create(:admin_user, password: "correct_pass", password_confirmation: "correct_pass") }

    it "returns the record when authenticate is called with the correct password" do
      expect(saved_user.authenticate("correct_pass")).to eq(saved_user)
    end

    it "returns false when authenticate is called with an incorrect password" do
      expect(saved_user.authenticate("wrong_pass")).to be_falsey
    end
  end

  describe "password storage" do
    let!(:saved_user) { create(:admin_user, password: "my_plain_password", password_confirmation: "my_plain_password") }

    it "does not store the plain-text password in password_digest" do
      expect(saved_user.password_digest).not_to eq("my_plain_password")
    end

    it "stores a bcrypt hash in password_digest" do
      expect(saved_user.password_digest).to match(/\A\$2[aby]\$/)
    end
  end
end
