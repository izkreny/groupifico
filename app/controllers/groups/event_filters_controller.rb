# WHY: what the events list shows is kept per browser rather than in the URL, the way the roster's order is, so a member's applied list and filters greet them on their next visit. Authorized as reading the group, because choosing how to look at its events writes nothing about them.
class Groups::EventFiltersController < ApplicationController
  include GroupScoped

  # WHY: a filter no longer applied is deleted rather than left standing, because a chip's ✕ applies everything else that was on, and the cookie it removes would otherwise outlive it.
  def update
    authorize! @group, to: :show?

    Event::Filter.new(Current.member, list: params[:scope], categories: params[:category], answers: params[:answer], managed: params[:managed]).to_cookies.each do |name, value|
      if value.present?
        cookies.permanent[name] = value
      else
        cookies.delete(name)
      end
    end

    redirect_to group_events_path(@group), status: :see_other
  end
end
