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

def populate_empty_database
  # Make Faker always produce same results aka enable deterministic output
  Faker::Config.random = Random.new(666)

  # Create 2 groups with unique 10 members in each group
  groups = FactoryBot.create_list(:group, 2, :with_all_attributes) do |group|
    FactoryBot.create_list(:member, 10, :with_all_attributes, group: group)
  end

  # Create two new users who are members of both groups
  FactoryBot.create_list(:user, 2, :with_full_profile) do |user|
    groups.each do |group|
      FactoryBot.create(:member, user: user, group: group)
    end
  end

  # Assign owner role to the first member of each group
  groups.each { it.members.first.owner! }

  # Create 10 past concluded events for both groups and add registrations
  groups.each do |group|
    options = {
      group: group,
      creator: group.members.first,
      manager: group.members.sample,
      address: nil
    }
    FactoryBot.create_list(:event, 10, :from_the_past, :with_all_attributes, :concluded, options) do |event|
      group.members.each do |member|
        FactoryBot.create(:registration, event: event, member: member, status: [ :yes, :maybe, :no ].sample)
      end
    end
  end

  # Create 10 future unconfirmed events for both groups and add registrations
  groups.each do |group|
    options = {
      group: group,
      creator: group.members.first,
      manager: group.members.sample,
      address: nil
    }
    FactoryBot.create_list(:event, 10, :from_the_future, :with_all_attributes, options) do |event|
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
