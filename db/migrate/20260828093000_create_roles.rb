class CreateRoles < ActiveRecord::Migration[8.1]
  # The legacy `members.role` enum, by its stored integer, mapped to the role a member keeps.
  # `member` is absent on purpose: belonging is the `Member` row, so it becomes no row at all.
  BACKFILL = { 0 => "owner", 2 => "administrator", 3 => "events_administrator" }.freeze

  def up
    create_table :roles do |t|
      t.belongs_to :member, null: false, foreign_key: { on_delete: :cascade, on_update: :cascade }
      t.string     :name,   null: false

      t.timestamps
    end

    add_index :roles, [ :member_id, :name ], unique: true

    backfill_roles

    remove_column :members, :role
  end

  # Raised rather than written: a member holding two roles has no representation in a single-value
  # column, so a reverse migration would have to pick one and lose the other silently.
  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private
    # Written in SQL rather than through the models, so a later change to `Role` cannot rewrite
    # what this migration did to rows that already exist.
    def backfill_roles
      now = connection.quote(Time.current)

      BACKFILL.each do |value, name|
        execute <<~SQL.squish
          INSERT INTO roles (member_id, name, created_at, updated_at)
          SELECT id, #{connection.quote(name)}, #{now}, #{now} FROM members WHERE role = #{value}
        SQL
      end
    end
end
