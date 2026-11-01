# Who is on the event's list, as one form: the new ticks reserve a place and the unticks remove one. A resource of the event's rather than `RegistrationsController#create`, because one submit both adds and removes.
class Events::RostersController < ApplicationController
  include GroupScoped

  # One message for every way a change can stop applying while the reader was choosing - registered by somebody else, paused, gone from the group, or already removed. It names none of them, because the controller cannot tell which happened and the reader's answer is the same either way: the list moved, here it is again.
  MOVED_ON = "Nothing changed: nobody you ticked is still on offer. Here it is again.".freeze

  before_action :set_event

  # The registering row of the events table is who this screen is for. Asked of a registration with no member on it, so `own?` is false and what is left is the three roles and the event's manager.
  def edit
    authorize! unattached_registration, to: :create?
  end

  # The statuses are written by `Event#update_roster` rather than posted, because `reserved` is the only thing a tick means here, so there is no posted status for a second question to ask about.
  #
  # WHY: removal is asked only when there is something to remove, of the same memberless record. A manager may reserve and may not remove, so their form posts no `listed_ids`, and a posted removal from them stops the whole request before any write rather than being dropped.
  def update
    authorize! unattached_registration, to: :create?

    ticked  = posted_ids(:member_ids)
    listed  = posted_ids(:listed_ids)
    leaving = @event.registrations.where(member_id: listed - ticked)
    authorize! unattached_registration, to: :destroy? if leaving.exists?

    reserved, removed = @event.update_roster(arriving: available_members(ticked), leaving:)

    if reserved.positive? || removed.positive?
      redirect_to group_event_path(@group, @event), status: :see_other, notice: updated_notice(reserved, removed)
    else
      # The two ways of changing nothing read the same to the controller and differently to the reader: one of them asked for a change, and telling them to make one sends them back to the row that moved out from under them.
      flash.now[:alert] = ticked.sort == listed.sort ? "Tick or untick somebody first." : MOVED_ON
      render :edit, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotUnique
    # The same move as the intersection in `available_members`, arriving too late for it: the row landed while this request was writing rather than before it read. The transaction has rolled the whole set back, so the answer is the same one.
    flash.now[:alert] = MOVED_ON
    render :edit, status: :unprocessable_content
  end

  private
    def set_event
      @event = @group.events.find(params.expect(:event_id))
    end

    def unattached_registration = Registration.new(event: @event)

    # Blanks dropped, because the screen posts a hidden empty entry so each key is always there.
    def posted_ids(key)
      params.expect(key => []).compact_blank
    end

    # Those of them the screen would still offer, rather than the ids as posted. They are unscoped: one naming somebody from another group would publish their name through the event's roster to people with no claim on it.
    #
    # It reads the set as it stands now, which closes the row that was registered while the form sat open and not the one registered while this request runs - that one reaches the unique index, and `update` rescues it.
    def available_members(ids)
      @group.members.active.without_registration_for(@event).where(id: ids)
    end

    def updated_notice(reserved, removed)
      if reserved.positive? && removed.positive?
        "#{helpers.pluralize(reserved, "place")} reserved, #{removed} removed."
      elsif reserved.positive?
        "#{helpers.pluralize(reserved, "place")} reserved."
      else
        "#{helpers.pluralize(removed, "place")} removed."
      end
    end
end
