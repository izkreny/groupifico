class RenameAttendeesToRegistrations < ActiveRecord::Migration[8.1]
  def change
    rename_table :attendees, :registrations
    rename_index :registrations, "index_attendees_on_event_id", "index_registrations_on_event_id"
    rename_index :registrations, "index_attendees_on_member_id_and_event_id", "index_registrations_on_member_id_and_event_id"
    rename_index :registrations, "index_attendees_on_member_id", "index_registrations_on_member_id"
  end
end
