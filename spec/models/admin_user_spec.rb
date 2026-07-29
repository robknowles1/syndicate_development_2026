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

  describe "blank password assignment" do
    it "rejects a blank password rather than silently keeping the old one" do
      # Arrange — has_secure_password's password= is a no-op on "", so the digest survives
      # and the length validation is skipped because password reads back nil
      user = create(:admin_user)
      original_digest = user.password_digest

      # Act
      updated = user.update(password: "", password_confirmation: "")

      # Assert
      expect(updated).to be(false)
      expect(user.errors[:password]).to be_present
      expect(user.reload.password_digest).to eq(original_digest)
    end

    it "still allows updates that leave the password alone" do
      # Arrange
      user = create(:admin_user)

      # Act / Assert
      expect(user.update(email: "renamed@example.com")).to be(true)
    end

    it "accepts a real password after a blank one was rejected" do
      # Arrange — the rejection must not stick to the record for the rest of its life
      user = create(:admin_user)
      user.update(password: "", password_confirmation: "")

      # Act
      updated = user.update(password: "a-perfectly-fine-password",
                            password_confirmation: "a-perfectly-fine-password")

      # Assert
      expect(updated).to be(true)
      expect(user.reload.authenticate("a-perfectly-fine-password")).to be_truthy
    end
  end

  describe "password-setting flows" do
    context "without a password key in the submitted attributes" do
      it "refuses to accept an invitation and keeps the placeholder digest" do
        # Arrange — permitted params omit keys the form did not send, so password= is never
        # called and neither the blank-assignment guard nor the length validation sees it
        user = described_class.find(create(:admin_user, :pending_invitation).id)
        placeholder_digest = user.password_digest

        # Act
        accepted = user.accept_invitation({})

        # Assert
        expect(accepted).to be(false)
        expect(user.errors[:password]).to be_present
        expect(user.reload.password_digest).to eq(placeholder_digest)
        expect(user.invitation_pending?).to be(true)
      end

      it "refuses to reset a password and keeps the existing digest" do
        # Arrange
        user = described_class.find(create(:admin_user).id)
        original_digest = user.password_digest

        # Act
        reset = user.reset_password({})

        # Assert
        expect(reset).to be(false)
        expect(user.errors[:password]).to be_present
        expect(user.reload.password_digest).to eq(original_digest)
      end

      it "refuses to change a password and keeps the existing digest" do
        # Arrange
        user = described_class.find(create(:admin_user).id)
        original_digest = user.password_digest

        # Act
        changed = user.change_password({})

        # Assert
        expect(changed).to be(false)
        expect(user.errors[:password]).to be_present
        expect(user.reload.password_digest).to eq(original_digest)
      end

      it "reports the missing password once rather than twice" do
        # Arrange — has_secure_password adds its own :blank error whenever the digest is
        # missing, and a duplicate would show the admin the same sentence twice
        user = described_class.find(create(:admin_user).id)

        # Act
        user.change_password({})

        # Assert
        expect(user.errors.where(:password, :blank).count).to eq(1)
      end
    end

    it "still allows a plain update that does not touch the password" do
      # Arrange
      user = create(:admin_user)

      # Act / Assert — only the flows that exist to set a password require one
      expect(user.update(email: "renamed@example.com")).to be(true)
    end
  end

  describe ".authenticate_by_email" do
    it "returns the admin for a correct password" do
      # Arrange
      user = create(:admin_user, email: "doug@example.com")

      # Act / Assert
      expect(described_class.authenticate_by_email("doug@example.com", "securepassword123")).to eq(user)
    end

    it "returns nil for a wrong password" do
      # Arrange
      create(:admin_user, email: "doug@example.com")

      # Act / Assert
      expect(described_class.authenticate_by_email("doug@example.com", "wrong-password")).to be_nil
    end

    it "performs a bcrypt comparison even when no account matches" do
      # Arrange — returning early on an unknown address makes it answer in a fraction of
      # the time a known one does, which is enough to enumerate registered addresses.
      # Spied on the hashing rather than on BCrypt::Password.new, which only parses a
      # digest string and so costs nothing: dropping the comparison would still satisfy it.
      allow(BCrypt::Engine).to receive(:hash_secret).and_call_original

      # Act
      described_class.authenticate_by_email("nobody@example.com", "any-password")

      # Assert — the submitted password, not the throwaway secret behind the dummy digest
      expect(BCrypt::Engine).to have_received(:hash_secret).with("any-password", anything)
    end

    it "costs the dummy comparison the same as a real one" do
      # Arrange — a cheaper dummy digest reintroduces the timing difference it exists to
      # hide, because bcrypt cost is the whole of the work being measured
      real_cost = BCrypt::Password.new(create(:admin_user).password_digest).cost

      # Act
      dummy_cost = BCrypt::Password.new(described_class.unmatchable_password_digest).cost

      # Assert
      expect(dummy_cost).to eq(real_cost)
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

    it "accepts an invitation given attributes without a confirmation key" do
      # Arrange — permitted params omit keys the form did not submit. Loaded fresh, as the
      # controller has it: the factory leaves a stale confirmation on the built instance.
      user = described_class.find(create(:admin_user, :pending_invitation).id)

      # Act
      accepted = user.accept_invitation({ "password" => "a-perfectly-fine-password" })

      # Assert
      expect(accepted).to be(true)
      expect(user.reload.active?).to be(true)
    end

    it "settles a pending invitation when the password is set through a reset" do
      # Arrange
      user = create(:admin_user, :pending_invitation)

      # Act
      user.reset_password(password: "a-perfectly-fine-password",
                          password_confirmation: "a-perfectly-fine-password")

      # Assert
      expect(user.reload.active?).to be(true)
    end

    it "leaves an existing acceptance timestamp alone on a later reset" do
      # Arrange
      user = create(:admin_user, invitation_accepted_at: 3.days.ago)
      original_acceptance = user.invitation_accepted_at

      # Act
      user.reset_password(password: "a-perfectly-fine-password",
                          password_confirmation: "a-perfectly-fine-password")

      # Assert
      expect(user.reload.invitation_accepted_at).to be_within(1.second).of(original_acceptance)
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
