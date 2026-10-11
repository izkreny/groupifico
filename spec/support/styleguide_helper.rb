module StyleguideHelper
  # The group `/styleguide` draws, planted for one example. The suite runs on a database `bin/ci` has just reset, so the group `db/seeds/styleguide.rb` creates is not there; this is the smallest group that gives every section a record to draw. Factories rather than the seed file, because whether specs read the seeds is #346's question.
  def plant_styleguide_group
    group  = create(:group, id: StyleguidesController::GROUP_ID, name: "Sample choir")
    owner  = create(:member, :active, :owner, group:, user: create(:user, :with_full_profile, first_name: "Ana", last_name: "Horvat"))
    asked  = create(:member, :active, group:, user: create(:user, :with_full_profile, first_name: "Ivan", last_name: "Kovačević"))
    coming = create(:member, :active, group:, user: create(:user, :with_full_profile, first_name: "Marija", last_name: "Babić"))

    next_up = create(:event, :from_the_future, group:, status: :confirmed, address: create(:address), creator: owner, manager: owner)
    create(:registration, event: next_up, member: asked, status: :invited)
    create(:registration, event: next_up, member: coming, status: :yes)

    unconfirmed = create(:event, :from_the_future, group:, status: :unconfirmed, creator: owner)
    create(:registration, event: unconfirmed, member: asked, status: :invited)

    ongoing = create(:event, :ongoing, group:, creator: owner)
    create(:registration, event: ongoing, member: coming, status: :yes)

    create(:event, :from_the_past, group:, status: :concluded, creator: owner)
    create(:event, :from_the_future, group:, status: :canceled, creator: owner)

    group
  end
end
