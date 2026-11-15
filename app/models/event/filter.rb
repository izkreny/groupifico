# What the events list shows its reader: one list, and any categories, answers and the reader's own managed events within it. Read from the URL when it carries any of the list's parameters, so a link shows what it names for that visit, and otherwise from the cookies the last applied choice wrote.
#
# WHY: every value the list does not offer is dropped on the way in rather than carried, the way `EventsHelper#roster_order` drops an order, so nothing outside these lists ever reaches a query or a cookie.
class Event::Filter
  # `nil` is the upcoming list, the screen's own URL.
  LISTS = { nil => "Upcoming", "past" => "Past", "canceled" => "Canceled" }.freeze
  # In the order the sheet offers them, which is also the order their chips take.
  CATEGORIES = { "gig" => "Gig", "rehearsal" => "Rehearsal", "other" => "Other" }.freeze
  ANSWERS = { "yes" => "Yes", "maybe" => "Maybe", "no" => "No", "not_answered" => "Not answered" }.freeze
  MANAGED = "Only events I manage".freeze

  # WHY: "Not answered" is a place on the event's list with no answer yet, so an event the reader is not listed on has no answer of theirs to match.
  STATUSES = { "yes" => %w[ yes ], "maybe" => %w[ maybe ], "no" => %w[ no ], "not_answered" => %w[ reserved response_requested ] }.freeze

  PARAMS = %w[ scope category answer managed ].freeze

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

  # Whether anything hides events from the chosen list; the list itself never counts, so the funnel says the same thing whichever list is open.
  def narrowed?
    categories.any? || answers.any? || managed?
  end

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

  # Each filter that is on, as the chip names it and the parameters that leave every other one standing.
  def chips
    categories.map { [ CATEGORIES[it], without(category: it) ] } +
      answers.map { [ ANSWERS[it], without(answer: it) ] } +
      (managed? ? [ [ MANAGED, without(managed: true) ] ] : [])
  end

  def to_params = without

  def save_to(cookies)
    { events_list: list, events_categories: categories.join(","), events_answers: answers.join(","), events_managed: (managed? ? "true" : nil) }.each do |name, value|
      if value.present?
        cookies.permanent[name] = value
      else
        cookies.delete(name)
      end
    end
  end

  private
    def without(category: nil, answer: nil, managed: false)
      { scope: list, category: categories - [ category ], answer: answers - [ answer ], managed: ("1" if managed? && !managed) }.compact_blank
    end
end
