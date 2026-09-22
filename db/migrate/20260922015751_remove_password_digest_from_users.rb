class RemovePasswordDigestFromUsers < ActiveRecord::Migration[8.1]
  def change
    # Sign-in is passwordless: an emailed link or code, never a password.
    remove_column :users, :password_digest, :string, null: false
  end
end
