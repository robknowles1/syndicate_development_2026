class AddInvitationFieldsToAdminUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :admin_users, :invited_at, :datetime
    add_column :admin_users, :invitation_accepted_at, :datetime

    # Every admin that exists before invitations did was created directly (seeds or
    # console) and already has a working password, so treat them as accepted. Without
    # this they are indistinguishable from a pending invite and would be locked out.
    execute <<~SQL
      UPDATE admin_users
      SET invitation_accepted_at = created_at
      WHERE invitation_accepted_at IS NULL
    SQL

    # The model normalizes email to lowercase, and normalization applies to finder
    # values too, so a row stored with mixed case would become unreachable by login.
    execute "UPDATE admin_users SET email = LOWER(TRIM(email))"
  end

  def down
    remove_column :admin_users, :invitation_accepted_at
    remove_column :admin_users, :invited_at
  end
end
