class StyleguidesController < ApplicationController
  # The group `db/seeds/styleguide.rb` creates for this page to draw.
  #
  # WHY: found by its name alone, so the seed takes whatever id the database hands it. Nothing makes a group's name unique, so it is one nobody would give their own group, which keeps a group created through the app from being drawn as the styleguide.
  GROUP_NAME = "Samplifichoir"

  # Permanent. The page draws seeded sample data for whoever opens it, a developer's page rather than a member's, so there is no decision for a policy to make. Named actions rather than a bare skip, so an action added later cannot inherit an exemption nobody chose for it - same reason `SessionsController` names its own.
  skip_verify_authorized only: %i[ show ]

  def show
    @group = Group.find_by(name: GROUP_NAME)
    @next_up, @unconfirmed, @ongoing, @concluded, @canceled = pick_events
    @owner, @paused = pick_members
    # WHY: the owner is active here, so a paused membership is in another group, which is what gives the switcher both a row that is not current and a paused one.
    @memberships = @owner ? @owner.user.current_memberships.preloaded.to_a : []

    if [ @next_up, @unconfirmed, @ongoing, @concluded, @canceled, @owner, @paused, @group&.address, @memberships.find(&:paused?) ].all?
      flash.now[:notice] = "Event was successfully updated."
      flash.now[:alert]  = "You are not allowed to do that."
    else
      render :missing
    end
  end

  private
    # One event per state the page draws, each picked by status rather than by name, so a spec's smaller planted group draws as well as the seeded one. The hero is the confirmed event still ahead, and the ongoing one stands for confirmed among the rows.
    #
    # WHY: nil for a state the group no longer holds, which renders the missing page. The seed writes its times relative to the day it ran, so its ongoing event ends a few days later and its confirmed one stops being ahead within months, and an old seed is then as unable to draw those as no seed at all.
    def pick_events
      events = @group ? @group.events.preloaded.to_a : []

      [
        events.find { it.confirmed? && it.starts_at.future? },
        events.find(&:unconfirmed?),
        events.find(&:ongoing?),
        events.find(&:concluded?),
        events.find(&:canceled?)
      ]
    end

    # An active owner, whose membership draws the owner tags and whose profile the account sections draw, and a paused member for the status tags. Each picked by status as the events are.
    def pick_members
      members = @group ? @group.members.preloaded.to_a : []

      [ members.find { it.active? && it.owner? }, members.find(&:paused?) ]
    end

    # Every control a permitted member sees, whoever opens the page. The visitor is rarely a member of the styleguide group, so the real policies would refuse most of them and the RSVP pills, among others, would vanish. Who is permitted is the policies' business and their specs', never this page's.
    def allowed_to?(*) = true
end
