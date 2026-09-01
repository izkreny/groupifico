class RemovePasswordDigestFromUsers < ActiveRecord::Migration[8.1]
  def change
    # Reversible only in shape, not in content: `up` again would leave every existing row without
    # the `null: false` value the column demands. Nothing is deployed yet - #76 is open - so no row
    # holds a digest worth carrying, and the reverse exists for a local `db:rollback` alone.
    remove_column :users, :password_digest, :string, null: false
  end
end
