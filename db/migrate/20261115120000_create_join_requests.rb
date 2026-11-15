class CreateJoinRequests < ActiveRecord::Migration[8.1]
  def change
    # WHY: a request belongs to the link it came through rather than to the group, so turning the link off or regenerating it deletes every request made through it, which #447 relies on to refuse them.
    create_table :join_requests do |t|
      t.belongs_to :join_link,    null: false, foreign_key: { on_delete: :cascade, on_update: :cascade }
      t.string     :email,        null: false, limit: 250
      t.string     :first_name,   null: false, limit: 250
      t.string     :last_name,    null: false, limit: 250
      t.string     :mobile_phone, null: false, limit: 50
      t.string     :token_digest, null: false, index: { unique: true }
      t.datetime   :expires_at,   null: false
      t.datetime   :consumed_at

      t.timestamps
    end
  end
end
