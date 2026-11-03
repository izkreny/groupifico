# WHY: the list's order is kept per browser rather than in the URL, because the answers, requests and reservations made on the list each redirect back to the event and would otherwise drop it. Checked as reading the event, because choosing how to look at the list writes nothing about it.
class Events::RosterOrdersController < ApplicationController
  include EventScoped

  # WHY: an order the list does not offer is dropped rather than stored, so the cookie only ever holds a value `Event#roster` knows.
  def update
    authorize! @event, to: :show?

    if order = params[:order].presence_in(Event::ROSTER_ORDERS)
      cookies.permanent[:roster_order] = order
    end

    redirect_back_or_to group_event_path(@group, @event), status: :see_other
  end
end
