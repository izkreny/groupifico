class Current < ActiveSupport::CurrentAttributes
  attribute :session

  # Assigned per request from `params[:group_id]`, by `GroupScoped`, because nothing already here
  # can derive it: `Current.session` is a `Session` that only `belongs_to :user`, and a user has
  # `groups` plural, so only the URL knows which group is being acted in. A controller that is not
  # nested under a group leaves it nil, and `member` answers nil with it.
  attribute :group

  # Defaulted rather than left nil, because `Group`'s `group_type` default reads this on every
  # instantiation and a console, a job or `db/seeds.rb` has no request to have set it. Without the
  # default that guard would move into the enum's lambda, where every reader of `Group` has to
  # know about it.
  #
  # The Proc is re-run on every reset - `resolve_defaults` calls it rather than sharing one value,
  # in activesupport's `current_attributes.rb` - so each request starts unbranded until
  # `ApplicationController` says otherwise.
  attribute :brand, default: -> { Brand.new(nil) }

  delegate :user, to: :session, allow_nil: true

  # Which membership is acting. A public instance method rather than an attribute, because it is
  # derived from two attributes rather than assigned: `CurrentAttributes.method_added` generates
  # the class-level delegator for every public instance method, so `Current.member` reads as an
  # attribute from the outside.
  #
  # Not memoized, deliberately. `reset` is `self.attributes = resolve_defaults` - it replaces the
  # attributes hash and touches nothing else - so an `@member ||=` ivar would survive the
  # executor's reset and hand the next request on this thread the previous request's member. If a
  # caller ever makes this hot, the fix is a second `attribute` assigned alongside `group`.
  #
  # No guard on `user` beyond the safe navigation: `members.user_id` is `NOT NULL`, so a signed-out
  # lookup matches nothing rather than matching a userless row. Both `&.` earn their place, since
  # `nil&.members.find_by` raises on `find_by` rather than short-circuiting.
  def member
    group&.members&.find_by(user: user)
  end
end
