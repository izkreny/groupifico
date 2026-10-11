class StyleguidesController < ApplicationController
  # The group `db/seeds/styleguide.rb` creates for this page to draw.
  #
  # WHY: 3, the id after the sample groups on a fresh database, so every id stays small. A replant continues SQLite's sequence past it rather than reusing it, so it never collides there either; a third sample group would take 3 first and fail the seed's create loudly.
  GROUP_ID = 3

  # Permanent. The page draws seeded sample data for whoever opens it, a developer's page rather than a member's, so there is no decision for a policy to make. Named actions rather than a bare skip, so an action added later cannot inherit an exemption nobody chose for it - same reason `SessionsController` names its own.
  skip_verify_authorized only: %i[ show ]

  def show
    @group = Group.find_by(id: GROUP_ID)
    @next_up, @unconfirmed, @ongoing, @concluded, @canceled = pick_events

    if [ @next_up, @unconfirmed, @ongoing, @concluded, @canceled ].all?
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

    # Every control a permitted member sees, whoever opens the page. The visitor is rarely a member of the styleguide group, so the real policies would refuse most of them and the RSVP pills, among others, would vanish. Who is permitted is the policies' business and their specs', never this page's.
    def allowed_to?(*) = true
end
