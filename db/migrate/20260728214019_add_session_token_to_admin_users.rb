class AddSessionTokenToAdminUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :admin_users, :session_token, :string
  end
end
