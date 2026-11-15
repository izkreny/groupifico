# WHY: one object decides what the events list shows, so the list, its chips, the funnel and the sheet cannot disagree. Every value the list does not offer is dropped on the way in, the way `EventsHelper#roster_order` drops an order, so nothing outside these lists reaches a query or a cookie.
class Event::Filter
  # WHY: `nil` is the upcoming list because that list is the screen's own URL, with no `scope`.
  LISTS = { nil => "Upcoming", "past" => "Past", "canceled" => "Canceled" }.freeze
  # WHY: in the sheet's order rather than the enum's, so the chips read in the order the sheet offers them.
  CATEGORIES = { "gig" => "Gig", "rehearsal" => "Rehearsal", "other" => "Other" }.freeze
  ANSWERS = { "yes" => "Yes", "maybe" => "Maybe", "no" => "No", "not_answered" => "Not answered" }.freeze
  MANAGED = "Only events I manage".freeze

  # WHY: "Not answered" is a place on the event's list with no answer yet, so an event the reader is not listed on has no answer of theirs to match.
  STATUSES = { "yes" => %w[ yes ], "maybe" => %w[ maybe ], "no" => %w[ no ], "not_answered" => %w[ reserved response_requested ] }.freeze

  PARAMS = %w[ scope category answer managed ].freeze

  # WHY: a URL carrying any of the list's parameters replaces the saved choice whole rather than merging with it, so a link shows exactly what it names, for that visit alone.
  def self.read(member, params:, cookies:)
    if params.keys.intersect?(PARAMS)
      new(member, list: params[:scope], categories: params[:category], answers: params[:answer], managed: params[:managed])
    else
      new(member, list: cookies[:events_list], categories: cookies[:events_categories]&.split(","), answers: cookies[:events_answers]&.split(","), managed: cookies[:events_managed])
    end
  end

  attr_reader :member, :list, :categories, :answers

  def initialize(member, list: nil, categories: nil, answers: nil, managed: nil)
    @member = member
    @list = list.presence_in(LISTS.keys.compact)
    @categories = CATEGORIES.keys & Array(categories)
    @answers = ANSWERS.keys & Array(answers)
    @managed = managed_offered? && ActiveModel::Type::Boolean.new.cast(managed).present?
  end

  def managed? = @managed

  # WHY: the Other group is offered only to a member it can narrow anything for, which is someone managing one of the group's events.
  def managed_offered?
    @managed_offered = member.managed_events.exists? unless defined?(@managed_offered)
    @managed_offered
  end

  # WHY: the list never counts, so the funnel says the same thing whichever list is open, and needs no idea of a default list that #462 will make depend on role.
  def narrowed?
    categories.any? || answers.any? || managed?
  end

  # WHY: ordered here because the list had no order of its own: the rows were whatever the database happened to return, which is the same list in a different sequence on a different day.
  def apply(events)
    events = case list
    when "past" then events.past.order(starts_at: :desc)
    when "canceled" then events.canceled.order(starts_at: :desc)
    else events.current_and_upcoming.order(:starts_at)
    end

    events = events.where(category: categories) if categories.any?
    events = events.where(manager: member) if managed?
    events = events.where(id: member.registrations.where(status: answers.flat_map { STATUSES[it] }).select(:event_id)) if answers.any?
    events
  end

  def list_name = LISTS.fetch(list)

  # WHY: each chip carries the parameters that leave every other filter on, so its ✕ applies what remains rather than knowing how to remove itself.
  def chips
    categories.map { [ CATEGORIES[it], without(category: it) ] } +
      answers.map { [ ANSWERS[it], without(answer: it) ] } +
      (managed? ? [ [ MANAGED, without(managed: true) ] ] : [])
  end

  def to_params = without

  def to_cookies
    { events_list: list, events_categories: categories.join(","), events_answers: answers.join(","), events_managed: ("true" if managed?) }
  end

  private
    def without(category: nil, answer: nil, managed: false)
      { scope: list, category: categories - [ category ], answer: answers - [ answer ], managed: ("1" if managed? && !managed) }.compact_blank
    end
end
