class AddFirstSignedInAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :first_signed_in_at, :datetime

    # Every account that exists before this column was made by signing up or signing in, so its
    # creation is when its owner first proved the address. Left empty, each would read as somebody
    # added and never seen.
    up_only { execute "UPDATE users SET first_signed_in_at = created_at" }
  end
end
