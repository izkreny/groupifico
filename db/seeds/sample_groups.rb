# Faker groups to click through by hand, one per address in this list: each address signs in as that group's active owner. Seeded as if started on `chorifico.com`, so development data looks like the domain the product is being built for rather than carrying the unbranded default: `Brand` answers the type, exactly as it does for a real request, instead of a literal type being named here.
SAMPLE_GROUP_OWNERS = %w[ owner.one@example.com owner.two@example.com ].freeze

groups = Current.set(brand: Brand.new("chorifico.com")) do
  FactoryBot.create_list(:group, SAMPLE_GROUP_OWNERS.size, :with_all_attributes)
end

# WHY: every combination is held once in each group by users who belong to all of them, rotated by one role set and one status per group, so switching groups as one user changes both what they may do and where they stand. The active owner's address is fixed in whichever group they own.
combinations = member_combinations
active_owner = [ [ Role::OWNER ], "active" ]
by_group = groups.each_index.map { combinations.rotate(it * (Member.statuses.size + 1)) }
shared_users = combinations.each_index.map do |index|
  if owned = by_group.index { it[index] == active_owner }
    FactoryBot.create(:user, :with_full_profile, email: SAMPLE_GROUP_OWNERS[owned])
  else
    FactoryBot.create(:user, :with_full_profile)
  end
end

groups.each_with_index do |group, group_index|
  members = shared_users.zip(by_group[group_index]).map { |user, combination| create_member(group:, user:, combination:) }
  owner   = members.find { it.active? && it.owner? }

  # The one duplicate combination worth seeding: with two active owners the guard in `Member` and `Role` lets an owner step down, with one it refuses, and the other groups keep one each.
  if group_index.zero?
    members << FactoryBot.create(:member, :owner, group:, user: FactoryBot.create(:user, :with_full_profile, email: "co-owner.one@example.com"))
  end

  members += Array.new(NUMBER_OF_MEMBERS_PER_GROUP - members.size) do
    FactoryBot.create(:member, :with_all_attributes, :any_status, group:)
  end

  addresses = [ group.address, FactoryBot.create(:address, :with_all_attributes) ]
  options   = { group:, creator: owner, address: nil }

  # One of the past half is the ongoing event instead, so the group has an event it is at right now.
  tenses = [ :from_the_past ] * (NUMBER_OF_EVENTS_PER_GROUP / 2 - 1) + [ :ongoing ] + [ :from_the_future ] * (NUMBER_OF_EVENTS_PER_GROUP / 2)
  events = tenses.map do |tense|
    FactoryBot.create(:event, tense, :with_all_attributes, manager: members.sample, **options)
  end

  events.each do |event|
    answer_then_settle(event, members.index_with { Registration.statuses.keys.sample })
    event.update!(address: addresses.sample)
  end
end
