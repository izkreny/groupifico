# WHY: what the events list shows is kept per browser rather than in the URL, the way the roster's order is, so a member's applied list and filters greet them on their next visit. Authorized as reading the group, because choosing how to look at its events writes nothing about them.
class Groups::EventFiltersController < ApplicationController
  include GroupScoped

  def update
    authorize! @group, to: :show?

    Event::Filter.new(Current.member, list: params[:scope], categories: params[:category], answers: params[:answer], managed: params[:managed]).save_to(cookies)

    redirect_to group_events_path(@group), status: :see_other
  end
end
