class Current < ActiveSupport::CurrentAttributes
  attribute :session

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
end
