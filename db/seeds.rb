# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

ACTIVE_RECORDS_MODELS = [
  Address,
  Event,
  Group,
  Member,
  Registration,
  User,
  UserProfile
].freeze
NUMBER_OF_GROUPS            = 2   # DO NOT CHANGE THIS! :) TODO: Make this configurable as well
NUMBER_OF_MEMBERS_PER_GROUP = 22  # Minimum is two!
NUMBER_OF_EVENTS_PER_GROUP  = 44  # Use even number!

def populate_empty_database
  # Make Faker always produce same results aka enable deterministic output
  Faker::Config.random = Random.new(666)

  # Create groups with unique members in each group
  groups = FactoryBot.create_list(:group, NUMBER_OF_GROUPS, :with_all_attributes) do |group|
    FactoryBot.create_list(:member, NUMBER_OF_MEMBERS_PER_GROUP - 1, :with_all_attributes, group: group)
  end

  # Create one member that belongs to each group
  FactoryBot.create_list(:user, 1, :with_full_profile) do |user|
    groups.each do |group|
      FactoryBot.create(:member, user: user, group: group)
    end
  end

  # Assign owner role to the first member of each group
  groups.each { it.members.first.owner! }

  # Create past concluded events for groups and add registrations
  groups.each do |group|
    options = {
      group: group,
      creator: group.members.first,
      manager: group.members.sample,
      address: nil
    }
    FactoryBot.create_list(:event, NUMBER_OF_EVENTS_PER_GROUP / 2, :from_the_past, :with_all_attributes, options) do |event|
      group.members.each do |member|
        FactoryBot.create(:registration, event: event, member: member, status: [ :yes, :maybe, :no ].sample)
      end
    end
  end

  # Create future events for groups and add registrations
  groups.each do |group|
    options = {
      group: group,
      creator: group.members.first,
      manager: group.members.sample,
      address: nil
    }
    FactoryBot.create_list(:event, NUMBER_OF_EVENTS_PER_GROUP / 2, :from_the_future, :with_all_attributes, options) do |event|
      group.members.each do |member|
        FactoryBot.create(:registration, event: event, member: member, status: [ :yes, :maybe, :no ].sample)
      end
    end
  end

  # Create two extra addresses, one for each group, and assign them randomly to all events for each group
  first_group_addresses  = [ groups.first.address,  FactoryBot.create(:address, :with_all_attributes) ]
  second_group_addresses = [ groups.second.address, FactoryBot.create(:address, :with_all_attributes) ]
  groups.first.events.each  { it.address = first_group_addresses.sample;  it.save }
  groups.second.events.each { it.address = second_group_addresses.sample; it.save }
end

if ACTIVE_RECORDS_MODELS.all?(&:none?)
  puts "Loading sample data from the 'db/seeds.rb' file..."
  populate_empty_database
else
  puts "Database is not empty! To load sample data from the 'db/seeds.rb' file, use 'rails db:reset' or 'rails db:seed:replant' command."
end
