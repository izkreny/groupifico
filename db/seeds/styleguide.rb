# The group the styleguide draws, for checking the visual style and the themes against every state a screen can show. Literal names throughout, so a screenshot of it reads the same on every run, and found by a fixed id rather than by its name, which nothing makes unique.
#
# WHY: 3, the id after the sample groups on a fresh database, so every id stays small. A replant continues SQLite's sequence past it rather than reusing it, so it never collides there either; a third sample group would take 3 first and fail this create loudly.
STYLEGUIDE_GROUP_ID = 3

STYLEGUIDE_NAMES = [
  "Ana Horvat", "Ivan Kovačević", "Marija Babić", "Luka Marić", "Petra Jurić", "Marko Novak",
  "Ivana Knežević", "Tomislav Vuković", "Katarina Matić", "Josip Perić", "Lucija Tomić", "Filip Pavlović",
  "Mia Božić", "Ante Grgić", "Sara Blažević", "Matej Šarić", "Elena Radić", "Karlo Lovrić",
  "Nika Kovač", "Dino Barišić", "Lana Vidović", "Bruno Kralj", "Ema Jukić", "Leon Petrović",
  "Klara Mlinarić", "David Bošnjak", "Iva Šimić", "Fran Klarić", "Dora Mikulić", "Roko Pavić",
  "Tea Herceg", "Jakov Golubić", "Lea Popović", "Nikola Rukavina", "Maja Bilić", "Borna Filipović",
  "Paula Đurić", "Vito Ćosić", "Hana Lončar", "Toni Zorić", "Rita Kolar", "Mateo Bašić",
  "Zara Varga", "Gabrijel Žagar"
].freeze
raise "STYLEGUIDE_NAMES holds #{STYLEGUIDE_NAMES.size} names for #{NUMBER_OF_MEMBERS_PER_GROUP} members" unless STYLEGUIDE_NAMES.size == NUMBER_OF_MEMBERS_PER_GROUP

community_hall = FactoryBot.create(:address, name: "Community hall", street_name: "Obala", building_number: "14", postal_code: "10000", city: "Zagreb")

group = Current.set(brand: Brand.new("chorifico.com")) do
  FactoryBot.create(:group, id: STYLEGUIDE_GROUP_ID, name: "Sample choir", description: "Thursday rehearsals, concerts in spring and before Christmas.", address: community_hall)
end

# Every combination once, a second active owner, and plain members filling the group to the size of the sample groups. The owners' addresses are fixed so signing in as one needs no lookup.
memberships = member_combinations.map { |combination| { combination: } }
memberships << { combination: [ [ Role::OWNER ], "active" ], email: "co-owner.styleguide@example.com" }
memberships += Array.new(NUMBER_OF_MEMBERS_PER_GROUP - memberships.size) { {} }
memberships.find { it[:combination] == [ [ Role::OWNER ], "active" ] }[:email] = "owner.styleguide@example.com"

members = STYLEGUIDE_NAMES.zip(memberships).map do |full_name, attributes|
  first_name, last_name = full_name.split
  user = FactoryBot.create(:user, :with_full_profile, first_name:, last_name:, **attributes.slice(:email))

  if combination = attributes[:combination]
    create_member(group:, user:, combination:)
  else
    FactoryBot.create(:member, :any_status, group:, user:)
  end
end
owner, co_owner = members.select { it.active? && it.owner? }

# One event per status, and the one the group is at right now. The names are the ones the styleguide drew before it read the database.
[
  { name: "Autumn concert rehearsal", tense: :from_the_future, status: :confirmed, category: :rehearsal, address: community_hall,
    description: "A full run of the programme, coats off by seven." },
  { name: "Christmas gig", tense: :from_the_future, status: :unconfirmed, category: :gig, address: community_hall, manager: nil },
  { name: "Sectional", tense: :ongoing, status: :confirmed },
  { name: "Summer concert", tense: :from_the_past, status: :concluded, category: :gig, address: community_hall },
  { name: "Open rehearsal", tense: :from_the_future, status: :canceled, category: :rehearsal }
].each_with_index do |attributes, index|
  event = FactoryBot.create(:event, attributes[:tense], group:, creator: owner, manager: co_owner, **attributes.except(:tense))

  # WHY: every status on every event, shifted by one per event so each member answers differently from one event to the next. `reserved` and `invited` on an event that is over are what nobody answering leaves behind, which `Registration` allows.
  statuses = Registration.statuses.keys.rotate(index)
  answer_then_settle(event, members.each_with_index.to_h { |member, position| [ member, statuses[position % statuses.size] ] })
end
