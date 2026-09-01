class CreateSignInTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :sign_in_tokens do |t|
      t.belongs_to :user,         null: false, foreign_key: { on_delete: :cascade, on_update: :cascade }
      t.string     :token_digest, null: false
      t.datetime   :expires_at,   null: false
      t.datetime   :consumed_at

      t.timestamps
    end

    # Unique because redemption matches on the digest alone: a second row carrying the same digest
    # would let one `UPDATE ... WHERE token_digest = ?` spend two links at once.
    add_index :sign_in_tokens, :token_digest, unique: true
  end
end
