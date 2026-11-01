# The element picker's store: each element the owner picks and comments on in the browser is one JSON line of `config.x.picks_file`, which the agent reads, and deletes a line from once it has worked that pick.
class PicksController < ApplicationController
  # WHY: only `config/environments/development.rb` sets the file, so the route the test environment also draws answers 404 there unless a spec sets it. Prepended for the reason `Styleguides::SessionsController` gives.
  prepend_before_action { raise ActionController::RoutingError, "Not Found" unless file }

  # WHY: the sign-in screens load the picker too, through `layouts/_head`, and a developer's tool behind the guard above has no decision for a policy to make. Named actions, for the reason `StyleguidesController` gives.
  allow_unauthenticated_access only: %i[ index create ]
  skip_verify_authorized only: %i[ index create ]
  skip_verify_authorized_scoped only: %i[ index ]

  def index
    render json: file.exist? ? file.each_line.reject(&:blank?).map { JSON.parse(it) } : []
  end

  def create
    file.open("a") { it.puts pick_params.to_h.to_json }

    head :created
  end

  private
    def file = Rails.configuration.x.picks_file

    def pick_params = params.expect(pick: [ :id, :page, :comment, :selector, :text, :html, templates: [] ])
end
