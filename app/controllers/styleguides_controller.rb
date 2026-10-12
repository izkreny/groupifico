class StyleguidesController < ApplicationController
  # The group `db/seeds/styleguide.rb` creates for this page to draw.
  #
  # WHY: found by its name alone, so the seed takes whatever id the database hands it. Nothing makes a group's name unique, so it is one nobody would give their own group, which keeps a group created through the app from being drawn as the styleguide.
  GROUP_NAME = "Samplifichoir"

  # Permanent. Opening the page is no decision: any signed-in developer may, and each control on it asks the signed-in user's own policies, which is what the member switcher is for. Named actions rather than a bare skip, so an action added later cannot inherit an exemption nobody chose for it - same reason `SessionsController` names its own.
  skip_verify_authorized only: %i[ show ]

  def show
    @group = Group.find_by(name: GROUP_NAME)
    @next_up, @unconfirmed, @ongoing, @concluded, @canceled = pick_events
    @members = @group ? @group.members.preloaded.order(:id).to_a : []
    @owner, @paused = pick_members
    # WHY: the owner is active here, so a paused membership is in another group, which is what gives the switcher both a row that is not current and a paused one.
    @memberships = @owner ? @owner.user.current_memberships.preloaded.to_a : []

    @missing = missing_records

    if @missing.empty?
      flash.now[:notice] = "Event was successfully updated."
      flash.now[:alert]  = "You are not allowed to do that."
    else
      render :missing
    end
  end

  private
    # What the page cannot draw, each by the name the missing page gives it. Without the group itself there is nothing else to name.
    def missing_records
      if @group
        {
          "a confirmed event still ahead"      => @next_up,
          "an unconfirmed event"               => @unconfirmed,
          "an event under way"                 => @ongoing,
          "a concluded event"                  => @concluded,
          "a canceled event"                   => @canceled,
          "an active owner"                    => @owner,
          "a paused member"                    => @paused,
          "a home address"                     => @group.address,
          "the owner paused in a second group" => @memberships.find(&:paused?)
        }.reject { |_name, record| record }.keys
      else
        [ "a group named #{GROUP_NAME}" ]
      end
    end

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
    #
    # WHY: from `@members`, in the order they joined, because the seed makes two active owners and only the first is paused in the second group the group switcher needs; an unordered read leaves which one is drawn to the database.
    def pick_members
      [ @members.find { it.active? && it.owner? }, @members.find(&:paused?) ]
    end
end
