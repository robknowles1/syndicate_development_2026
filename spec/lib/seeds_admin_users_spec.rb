require "rails_helper"

RSpec.describe "db/seeds.rb admin user seeding" do
  def with_admin_seed_password(value)
    original = ENV["ADMIN_SEED_PASSWORD"]
    value.nil? ? ENV.delete("ADMIN_SEED_PASSWORD") : ENV["ADMIN_SEED_PASSWORD"] = value
    yield
  ensure
    original.nil? ? ENV.delete("ADMIN_SEED_PASSWORD") : ENV["ADMIN_SEED_PASSWORD"] = original
  end

  describe "the ADMIN_SEED_PASSWORD guard" do
    context "when ADMIN_SEED_PASSWORD is not set" do
      it "raises naming the variable and writes nothing" do
        # Arrange
        seeding = -> { with_admin_seed_password(nil) { Rails.application.load_seed } }

        # Act & Assert
        expect { seeding.call }.to raise_error(/ADMIN_SEED_PASSWORD is not set/)
        expect(AdminUser.count).to eq(0)
        expect(HomePageContent.count).to eq(0)
      end
    end

    context "when ADMIN_SEED_PASSWORD is set to an empty string" do
      it "raises rather than silently creating no admin" do
        # Arrange
        seeding = -> { with_admin_seed_password("") { Rails.application.load_seed } }

        # Act & Assert
        expect { seeding.call }.to raise_error(/ADMIN_SEED_PASSWORD is set but blank/)
        expect(AdminUser.count).to eq(0)
      end
    end

    context "when ADMIN_SEED_PASSWORD is whitespace only" do
      it "raises rather than treating the whitespace as a password" do
        # Arrange
        seeding = -> { with_admin_seed_password("      ") { Rails.application.load_seed } }

        # Act & Assert
        expect { seeding.call }.to raise_error(/ADMIN_SEED_PASSWORD is set but blank/)
        expect(AdminUser.count).to eq(0)
      end
    end

    context "when ADMIN_SEED_PASSWORD is shorter than the model minimum" do
      it "raises reporting the minimum" do
        # Arrange
        too_short = "a" * (AdminUser::MINIMUM_PASSWORD_LENGTH - 1)
        seeding = -> { with_admin_seed_password(too_short) { Rails.application.load_seed } }

        # Act & Assert
        expect { seeding.call }.to raise_error(/ADMIN_SEED_PASSWORD is too short/)
        expect(AdminUser.count).to eq(0)
      end
    end

    context "when ADMIN_SEED_PASSWORD exceeds the bytes bcrypt will hash" do
      it "raises rather than seeding a silently truncated password" do
        # Arrange
        too_long = "a" * (ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED + 1)
        seeding = -> { with_admin_seed_password(too_long) { Rails.application.load_seed } }

        # Act & Assert
        expect { seeding.call }.to raise_error(/ADMIN_SEED_PASSWORD is too long/)
        expect(AdminUser.count).to eq(0)
      end
    end
  end

  describe "the seeded admin accounts" do
    context "with a valid ADMIN_SEED_PASSWORD on an empty database" do
      it "creates both admins, each able to authenticate" do
        # Arrange
        password = "seed-password-1234"

        # Act
        with_admin_seed_password(password) { Rails.application.load_seed }

        # Assert
        expect(AdminUser.pluck(:email)).to contain_exactly(
          "robknowles105@gmail.com",
          "haskettd@live.com"
        )
        expect(AdminUser.all).to all(be_active)
        expect(AdminUser.find_by(email: "robknowles105@gmail.com").authenticate(password)).to be_truthy
        expect(AdminUser.find_by(email: "haskettd@live.com").authenticate(password)).to be_truthy
      end
    end

    context "when seeding runs a second time against existing admins" do
      it "neither duplicates the accounts nor resets their passwords" do
        # Arrange
        original_password = "seed-password-1234"
        with_admin_seed_password(original_password) { Rails.application.load_seed }
        digests_before = AdminUser.order(:email).pluck(:password_digest)

        # Act
        with_admin_seed_password("a-different-password") { Rails.application.load_seed }

        # Assert
        expect(AdminUser.count).to eq(2)
        expect(AdminUser.order(:email).pluck(:password_digest)).to eq(digests_before)
        expect(AdminUser.find_by(email: "haskettd@live.com").authenticate(original_password)).to be_truthy
      end
    end

    context "when an admin seeded at the retired address is already present" do
      it "adds the current admins without raising and leaves the old row untouched" do
        # Arrange
        retired_digest = AdminUser.create!(
          email: "doug@syndicate-development.com",
          password: "retired-password-1234",
          password_confirmation: "retired-password-1234"
        ).password_digest

        # Act
        with_admin_seed_password("seed-password-1234") { Rails.application.load_seed }

        # Assert
        expect(AdminUser.pluck(:email)).to contain_exactly(
          "doug@syndicate-development.com",
          "robknowles105@gmail.com",
          "haskettd@live.com"
        )
        expect(AdminUser.find_by(email: "doug@syndicate-development.com").password_digest).to eq(retired_digest)
      end
    end
  end
end
