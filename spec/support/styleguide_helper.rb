module StyleguideHelper
  # The group `/styleguide` draws, planted for one example. The suite runs on a database `bin/ci` has just reset, so the group `db/seeds/styleguide.rb` creates is not there; this is the smallest group that gives every section a record to draw. Factories rather than the seed file, because whether specs read the seeds is #346's question.
  #
  # WHY: the members' names are arguments, so an example asserting one passes it and its precondition sits in its own body; the defaults serve the examples that assert none.
  def plant_styleguide_group(manager: "Ana Horvat", waiting: "Ivan Kovačević", said_yes: "Marija Babić")
    group  = create(:group, name: StyleguidesController::GROUP_NAME, address: create(:address))
    owner  = create(:member, :active, :owner, group:, user: planted_user(manager))
    asked  = create(:member, :active, group:, user: planted_user(waiting))
    coming = create(:member, :active, group:, user: planted_user(said_yes))
    create(:member, :paused, group:, user: planted_user("Luka Marić"))
    create(:member, :paused, group: create(:group), user: owner.user)

    next_up = create(:event, :from_the_future, group:, status: :confirmed, address: create(:address), creator: owner, manager: owner)
    create(:registration, event: next_up, member: asked, status: :response_requested)
    create(:registration, event: next_up, member: coming, status: :yes)

    unconfirmed = create(:event, :from_the_future, group:, status: :unconfirmed, creator: owner)
    create(:registration, event: unconfirmed, member: asked, status: :response_requested)

    ongoing = create(:event, :ongoing, group:, creator: owner)
    create(:registration, event: ongoing, member: coming, status: :yes)

    create(:event, :from_the_past, group:, status: :concluded, creator: owner)
    create(:event, :from_the_future, group:, status: :canceled, creator: owner)

    group
  end

  # A member of the planted group, by the name `plant_styleguide_group` gave them, so an example signs in as the member it means rather than reaching for a row by position.
  def planted_member(full_name)
    first_name, last_name = full_name.split
    Member.joins(:profile, :group).find_by!(groups: { name: StyleguidesController::GROUP_NAME }, user_profiles: { first_name:, last_name: })
  end

  private
    def planted_user(full_name)
      first_name, last_name = full_name.split
      create(:user, :with_full_profile, first_name:, last_name:)
    end
end
