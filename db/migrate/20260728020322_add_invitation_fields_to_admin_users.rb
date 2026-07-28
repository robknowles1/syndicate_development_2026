class AddInvitationFieldsToAdminUsers < ActiveRecord::Migration[8.1]
  # A migration-local model so this keeps behaving the same when AdminUser's validations,
  # normalizations, or defaults change later.
  class MigratedAdminUser < ActiveRecord::Base
    self.table_name = "admin_users"
  end

  class CollidingEmailsError < StandardError; end

  def up
    # Runs before any DDL so a deploy that cannot proceed stops having changed nothing,
    # rather than relying on the DDL transaction to unwind it.
    check_for_colliding_emails!

    add_column :admin_users, :invited_at, :datetime
    add_column :admin_users, :invitation_accepted_at, :datetime

    # check_for_colliding_emails! above loaded the model's columns before the DDL ran, so
    # everything below would otherwise operate on a schema that predates this migration.
    MigratedAdminUser.reset_column_information

    # Every admin that exists before invitations did was created directly (seeds or
    # console) and already has a working password, so treat them as accepted. Without
    # this they are indistinguishable from a pending invite and would be locked out.
    execute <<~SQL
      UPDATE admin_users
      SET invitation_accepted_at = created_at
      WHERE invitation_accepted_at IS NULL
    SQL

    normalize_emails!
  end

  # Lossy, and not safely reversible. The invitation timestamps are dropped and the email
  # normalization above is not undone, but the damage is on the way back up: the backfill in
  # #up cannot tell a rolled-back pending invitation from an admin who predates invitations,
  # so re-running marks every still-pending invitee as accepted. They end up active, holding
  # the random placeholder they were never told, with an invitation link that no longer
  # resolves — locked out with no way back in but a password reset.
  #
  # Re-invite anyone whose invitation was outstanding before rolling this back.
  def down
    remove_column :admin_users, :invitation_accepted_at
    remove_column :admin_users, :invited_at
  end

  def check_for_colliding_emails!
    collisions = MigratedAdminUser.pluck(:email)
      .group_by { |email| normalize(email) }
      .select { |_normalized, originals| originals.length > 1 }

    return if collisions.empty?

    raise CollidingEmailsError, <<~MESSAGE
      Cannot normalize admin_users.email: these addresses collide once trimmed and
      downcased, and the unique index would reject the update.

      #{collisions.map { |normalized, originals| "  #{normalized} <- #{originals.inspect}" }.join("\n")}

      Delete or correct the duplicate admin_users rows, then run this migration again.
    MESSAGE
  end

  # Done row by row in Ruby rather than as one UPDATE, because Postgres TRIM strips spaces
  # only while the model's normalizes uses String#strip, which also strips tabs and
  # newlines. A SQL-normalized row could keep whitespace the model always strips, leaving
  # it permanently unfindable by login.
  def normalize_emails!
    MigratedAdminUser.find_each do |admin_user|
      normalized = normalize(admin_user.email)
      next if normalized == admin_user.email

      admin_user.update_column(:email, normalized)
    end
  end

  private

  def normalize(email)
    email.to_s.strip.downcase
  end
end
