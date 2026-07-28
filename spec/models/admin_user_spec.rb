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

  describe "email normalization" do
    it "downcases and strips on write" do
      # Arrange / Act
      user = create(:admin_user, email: "  MixedCase@Example.COM  ")

      # Assert
      expect(user.email).to eq("mixedcase@example.com")
    end

    it "normalizes finder values, so lookup is case-insensitive" do
      # Arrange
      user = create(:admin_user, email: "doug@example.com")

      # Assert — the login lookup depends on this
      expect(AdminUser.find_by(email: "DOUG@Example.COM")).to eq(user)
      expect(AdminUser.find_by(email: "  doug@example.com ")).to eq(user)
    end

    it "treats differently-cased addresses as duplicates" do
      # Arrange
      create(:admin_user, email: "doug@example.com")

      # Act
      duplicate = build(:admin_user, email: "DOUG@EXAMPLE.COM")

      # Assert
      expect(duplicate).not_to be_valid
    end
  end

  describe "password length" do
    it "rejects a password below the minimum" do
      # Arrange / Act
      user = build(:admin_user, password: "a" * (described_class::MINIMUM_PASSWORD_LENGTH - 1),
                                password_confirmation: "a" * (described_class::MINIMUM_PASSWORD_LENGTH - 1))

      # Assert
      expect(user).not_to be_valid
    end

    it "accepts a password at the minimum" do
      # Arrange / Act
      user = build(:admin_user, password: "a" * described_class::MINIMUM_PASSWORD_LENGTH,
                                password_confirmation: "a" * described_class::MINIMUM_PASSWORD_LENGTH)

      # Assert
      expect(user).to be_valid
    end

    it "allows updates that do not touch the password" do
      # Arrange — existing admins keep working even if their stored password predates
      # the minimum-length rule, because validation is skipped when password is nil
      user = create(:admin_user)

      # Act / Assert
      expect(user.update(email: "renamed@example.com")).to be(true)
    end
  end

  describe "invitation state" do
    it "is pending when invited but not accepted" do
      # Arrange / Act
      user = create(:admin_user, :pending_invitation)

      # Assert
      expect(user.invitation_pending?).to be(true)
      expect(user.active?).to be(false)
    end

    it "becomes active once the invitation is accepted" do
      # Arrange
      user = create(:admin_user, :pending_invitation)

      # Act
      user.accept_invitation(password: "a-perfectly-fine-password",
                             password_confirmation: "a-perfectly-fine-password")

      # Assert
      expect(user.reload.active?).to be(true)
    end

    it "treats a directly created admin as active" do
      # Assert — seeds and console-created admins never went through an invitation
      expect(create(:admin_user).active?).to be(true)
    end
  end

  describe "token generation" do
    it "invalidates an invitation token once the password is set" do
      # Arrange
      user = create(:admin_user, :pending_invitation)
      token = user.generate_token_for(:invitation)

      # Act
      user.accept_invitation(password: "a-perfectly-fine-password",
                             password_confirmation: "a-perfectly-fine-password")

      # Assert
      expect(described_class.find_by_token_for(:invitation, token)).to be_nil
    end

    it "invalidates a reset token once the password changes" do
      # Arrange
      user = create(:admin_user)
      token = user.generate_token_for(:password_reset)

      # Act
      user.update(password: "a-perfectly-fine-password", password_confirmation: "a-perfectly-fine-password")

      # Assert
      expect(described_class.find_by_token_for(:password_reset, token)).to be_nil
    end

    it "does not accept an invitation token in the password reset slot" do
      # Arrange — the two purposes must not be interchangeable
      user = create(:admin_user)
      invitation_token = user.generate_token_for(:invitation)

      # Assert
      expect(described_class.find_by_token_for(:password_reset, invitation_token)).to be_nil
    end
  end
end
