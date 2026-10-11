class StyleguidesController < ApplicationController
  # The group `db/seeds/styleguide.rb` creates for this page to draw.
  #
  # WHY: 3, the id after the sample groups on a fresh database, so every id stays small. A replant continues SQLite's sequence past it rather than reusing it, so it never collides there either; a third sample group would take 3 first and fail the seed's create loudly.
  GROUP_ID = 3

  # Permanent. Every record on the page is a sample built for it and belongs to nobody, so there is
  # no decision for a policy to make. Named actions rather than a bare skip, so an action added
  # later cannot inherit an exemption nobody chose for it - same reason `SessionsController` names
  # its own.
  skip_verify_authorized only: %i[ show ]

  def show
    flash.now[:notice] = "Event was successfully updated."
    flash.now[:alert]  = "You are not allowed to do that."
  end

  private
    # Every control a permitted reader sees. The samples sit in a group no `Member` row belongs to,
    # so the real policies would refuse all of them and the RSVP pills, among others, would vanish.
    # Who is permitted is the policies' business and their specs', never this page's.
    def allowed_to?(*) = true
end
