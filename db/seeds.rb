# This file should ensure the existence of records required to run the application in every environment (production, development, test). The code here should be idempotent so that it can be executed at any point in every environment. The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

require "active_support/testing/time_helpers"

ACTIVE_RECORDS_MODELS = [
  Address,
  Event,
  Group,
  Member,
  Registration,
  User,
  UserProfile
].freeze
NUMBER_OF_MEMBERS_PER_GROUP = 44  # Every combination below, plus a second active owner! Also `STYLEGUIDE_NAMES`' length.
NUMBER_OF_EVENTS_PER_GROUP  = 44  # Use even number!


# Every role set the member form can produce, held under every member status. The form greys a role that another one it holds already implies, so a set where one role implies another is one nobody can reach, and derived from `Role::NAMES` rather than listed, a new role arrives seeded.
def member_combinations
  role_sets = (0..Role::NAMES.size).flat_map { Role::NAMES.combination(it).to_a }
  reachable = role_sets.reject { |names| names.any? { |name| names.any? { Role.new(name:).implies?(it) } } }

  reachable.product(Member.statuses.keys)
end

def create_member(group:, user:, combination:)
  names, status = combination

  FactoryBot.create(:member, group:, user:, status:, roles: names.map { Role.new(name: it) })
end

def drawn_member_status
  %i[ active active active active active active paused inactive ].sample # Rig the odds for :active 🎲
end

# Everyone answers, and only then is the event settled, because that is the order it happens in: people say whether they are coming, and afterwards somebody concludes it or calls it off. `Registration` refuses an answer to an event that is already over, so writing the outcome first would seed a history that could not have occurred. The caller decides which status each member holds, and the factory traits stay the authority on which outcome each event ends up with.
def answer_then_settle(event, statuses)
  outcome = event.status
  event.update!(status: :confirmed)

  statuses.each do |member, status|
    FactoryBot.create(:registration, event:, member:, status:)
  end

  event.update!(status: outcome)
end

# WHY: every random choice, Faker's included, draws from Ruby's one global generator, which `srand` seeds: Faker falls back to the `Random` class when nothing configures it, and `Array#sample` reads the same generator. One frozen clock makes every `ago` and every timestamp the same instant, so two runs write the same rows at the same offsets from the day they ran.
def populate_empty_database
  srand(666)

  extend ActiveSupport::Testing::TimeHelpers
  travel_to(Time.current) do
    require_relative "seeds/sample_groups"
    # Last, because its id is fixed and SQLite's `AUTOINCREMENT` continues from the highest id.
    require_relative "seeds/styleguide"
  end
end

if ACTIVE_RECORDS_MODELS.all?(&:none?)
  puts "Loading sample data from the 'db/seeds.rb' file..."
  populate_empty_database
else
  puts "Database is not empty! To load sample data from the 'db/seeds.rb' file, use 'rails db:reset' or 'rails db:seed:replant' command."
end
