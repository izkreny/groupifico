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

  options = { group:, creator: owner }

  # Half are rehearsals at the group's own address, on the Tuesdays and Thursdays either side of today at 6 pm. The last one before today happened and nobody has concluded it yet, one earlier one was called off, the rest are concluded, and every one still to come is confirmed.
  rehearsal_count = NUMBER_OF_EVENTS_PER_GROUP / 2
  days = ((Date.current - 90)..(Date.current + 90)).select { it.tuesday? || it.thursday? }
  past_days, upcoming_days = days.partition { it < Date.current }
  past_days = past_days.last(rehearsal_count / 2)
  upcoming_days = upcoming_days.first(rehearsal_count - past_days.size)

  past_statuses = Array.new(past_days.size, :concluded)
  past_statuses[-1] = :confirmed
  past_statuses[rand(past_days.size - 1)] = :canceled

  scheduled = past_days.zip(past_statuses) + upcoming_days.map { [ it, :confirmed ] }
  rehearsals = scheduled.map do |day, status|
    FactoryBot.create(:event, :rehearsal, :with_all_attributes, starts_at: day + 18.hours, status:, address: group.address, manager: members.sample, **options)
  end

  # The rest are other events at four addresses of their own, the one the group is at right now taking a place among the past half.
  other_count = NUMBER_OF_EVENTS_PER_GROUP - rehearsal_count
  other_addresses = FactoryBot.create_list(:address, 4, :with_all_attributes)
  tenses = [ :from_the_past ] * (other_count / 2 - 1) + [ :ongoing ] + [ :from_the_future ] * (other_count / 2)
  others = tenses.map do |tense|
    FactoryBot.create(:event, tense, :with_all_attributes, address: other_addresses.sample, manager: members.sample, **options)
  end

  (rehearsals + others).each do |event|
    answer_then_settle(event, members.index_with { Registration.statuses.keys.sample })
  end
end
