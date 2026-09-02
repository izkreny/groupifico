class CreateSignUps < ActiveRecord::Migration[8.1]
  def change
    # No `belongs_to :user`, and no foreign key anywhere: the point of the row is that no user
    # exists yet. The address is a domain fact here rather than a reference, which is why it is
    # carried as a string and resolved only at confirmation.
    create_table :sign_ups do |t|
      t.string   :email,        null: false, limit: 250
      t.string   :group_name,   null: false, limit: 250
      t.string   :token_digest, null: false
      t.datetime :expires_at,   null: false
      t.datetime :consumed_at

      t.timestamps
    end

    # Unique because redemption matches on the digest alone: a second row carrying the same digest
    # would let one `UPDATE ... WHERE token_digest = ?` spend two requests at once.
    add_index :sign_ups, :token_digest, unique: true
  end
end
