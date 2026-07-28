require "rails_helper"
require Rails.root.join("db/migrate/20260728020322_add_invitation_fields_to_admin_users")

RSpec.describe AddInvitationFieldsToAdminUsers do
  def unvalidated_admin_user(email)
    described_class::MigratedAdminUser.create!(email: email, password_digest: BCrypt::Password.create("x"))
  end

  # Postgres rolls DDL back with the surrounding transaction, so the schema returns on its
  # own. The cached column lists do not, and a stale one would follow this example into
  # every later one in the run.
  def forget_cached_columns
    AdminUser.reset_column_information
    described_class::MigratedAdminUser.reset_column_information
  end

  describe "#up" do
    it "sees the columns it has just added" do
      # Arrange — check_for_colliding_emails! reads the model before any DDL runs, so its
      # cached column list predates the migration and everything after the add_column calls
      # would otherwise work against a schema that is missing them
      migration = described_class.new
      migration.suppress_messages { migration.down }
      forget_cached_columns

      # Act
      migration.suppress_messages { migration.up }

      # Assert
      expect(described_class::MigratedAdminUser.column_names)
        .to include("invited_at", "invitation_accepted_at")
    ensure
      forget_cached_columns
    end
  end

  describe "#down" do
    it "leaves a still-pending invitee marked accepted once the migration is re-run" do
      # Arrange — the documented reason this migration is not safely reversible
      invitee = create(:admin_user, :pending_invitation, email: "invitee@example.com")
      migration = described_class.new

      # Act
      migration.suppress_messages { migration.down }
      migration.suppress_messages { migration.up }

      # Assert — the backfill cannot tell a rolled-back invitation from an admin who
      # predates invitations, so the invitee is left active holding a placeholder password
      # they were never told, with an invitation link that no longer resolves
      expect(invitee.reload.invitation_accepted_at).to be_present
      expect(invitee.active?).to be(true)
    ensure
      forget_cached_columns
    end
  end

  describe "#check_for_colliding_emails!" do
    it "passes when no two addresses normalize to the same value" do
      # Arrange
      unvalidated_admin_user("doug@example.com")
      unvalidated_admin_user("colleague@example.com")

      # Act / Assert
      expect { described_class.new.check_for_colliding_emails! }.not_to raise_error
    end

    it "aborts before any schema change when two addresses would collide" do
      # Arrange — the unique index rejects the UPDATE, which would otherwise surface as a
      # PG::UniqueViolation part-way through a deploy
      unvalidated_admin_user("Doug@Example.com")
      unvalidated_admin_user("doug@example.com")

      # Act / Assert
      expect { described_class.new.check_for_colliding_emails! }
        .to raise_error(described_class::CollidingEmailsError)
    end

    it "names the offending addresses so the failure can be acted on" do
      # Arrange
      unvalidated_admin_user("Doug@Example.com")
      unvalidated_admin_user("doug@example.com")

      # Act / Assert
      expect { described_class.new.check_for_colliding_emails! }
        .to raise_error(/doug@example\.com/)
    end

    it "treats addresses differing only by surrounding whitespace as colliding" do
      # Arrange
      unvalidated_admin_user("doug@example.com")
      unvalidated_admin_user("  doug@example.com  ")

      # Act / Assert
      expect { described_class.new.check_for_colliding_emails! }
        .to raise_error(described_class::CollidingEmailsError)
    end
  end

  describe "#normalize_emails!" do
    it "downcases and trims stored addresses" do
      # Arrange
      admin_user = unvalidated_admin_user("  MixedCase@Example.COM  ")

      # Act
      described_class.new.normalize_emails!

      # Assert
      expect(admin_user.reload.email).to eq("mixedcase@example.com")
    end

    it "strips the whitespace the model strips, not merely the spaces SQL TRIM strips" do
      # Arrange — Postgres TRIM removes spaces only, so a tab or newline left behind would
      # make the row permanently unfindable by a login that normalizes with String#strip
      admin_user = unvalidated_admin_user("\tdoug@example.com\n")

      # Act
      described_class.new.normalize_emails!

      # Assert
      expect(admin_user.reload.email).to eq("doug@example.com")
      expect(AdminUser.find_by(email: "doug@example.com")).to be_present
    end

    it "leaves an already-normalized address untouched" do
      # Arrange
      admin_user = unvalidated_admin_user("doug@example.com")

      # Act
      described_class.new.normalize_emails!

      # Assert
      expect(admin_user.reload.email).to eq("doug@example.com")
    end
  end
end
