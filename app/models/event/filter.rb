# WHY: one object decides what the events list shows, so the list, its chips, the funnel and the sheet cannot disagree. Every value the list does not offer is dropped on the way in, the way `EventsHelper#roster_order` drops an order, so nothing outside these lists reaches a query or a link.
class Event::Filter
  include ListFilter

  TAB = :scope
  # WHY: `nil` is the upcoming list because that list is the screen's own URL, with no `scope`.
  TABS = { nil => "Upcoming", "past" => "Past", "to_do" => "To do", "canceled" => "Canceled" }.freeze
  # WHY: the events waiting on whoever runs them are the `EventPolicy#oversee?` columns' read, so the tab is theirs alone, the way Pending is on the members list.
  OVERSEER_TABS = %w[ to_do ].freeze
  # WHY: in the sheet's order rather than the enum's, so the chips read in the order the sheet offers them.
  CATEGORIES = { "gig" => "Gig", "rehearsal" => "Rehearsal", "other" => "Other" }.freeze
  ANSWERS = { "yes" => "Yes", "maybe" => "Maybe", "no" => "No", "not_answered" => "Not answered" }.freeze
  MISCELLANEOUS = { "managed" => "Managed by me" }.freeze

  # WHY: "Not answered" is a place on the event's list with no answer yet, so an event the reader is not listed on has no answer of theirs to match.
  STATUSES = Registration::ANSWERS.index_with { [ it ] }.merge("not_answered" => Registration.statuses.keys - Registration::ANSWERS).freeze

  # WHY: the URL is the only place a filter lives, so a link shows exactly what it names and a plain visit opens on Upcoming with nothing on, with no remembered state to surprise anyone. Whether the reader oversees the events is the policy's answer, so the controller asks it and hands it in, as it does for `Member::Filter`.
  def self.from(member, params, oversees:)
    new(member, oversees:, scope: params[:scope], categories: params[:category], answers: params[:answer], managed: params[:managed])
  end

  attr_reader :member, :scope, :categories, :answers

  def initialize(member, oversees: false, scope: nil, categories: nil, answers: nil, managed: nil)
    @member = member
    @oversees = oversees
    @scope = scope.presence_in(offered_tabs.keys.compact)
    @categories = CATEGORIES.keys & Array(categories)
    @answers = ANSWERS.keys & Array(answers)
    # WHY: only the "1" the sheet sends, checked like every other value against what the sheet offers, since a boolean cast reads any unknown string as on.
    @managed = managed_offered? && managed.to_s == "1"
  end

  def tab = scope

  def oversees? = @oversees

  def offered_tabs = oversees? ? TABS : TABS.except(*OVERSEER_TABS)

  def managed? = @managed

  # WHY: the Miscellaneous group is offered only to a member it can narrow anything for, which is someone managing one of the group's events.
  def managed_offered?
    @managed_offered = member.managed_events.exists? unless defined?(@managed_offered)
    @managed_offered
  end

  def apply(events) = on_tab(narrow(events), scope)

  # WHY: every filter but the tab's own, as GitLab's issue tabs count, because the list carries no result line above its rows, so a total that ignored a chip would contradict the rows beneath it.
  def counts(events)
    narrowed = narrow(events)
    offered_tabs.keys.index_with { on_tab(narrowed, it).count }
  end

  # WHY: each chip carries the parameters that leave every other filter on, so its ✕ applies what remains rather than knowing how to remove itself.
  def chips
    categories.map { [ CATEGORIES[it], params_with(categories: categories - [ it ]) ] } +
      answers.map { [ ANSWERS[it], params_with(answers: answers - [ it ]) ] } +
      (managed? ? [ [ MISCELLANEOUS["managed"], params_with(managed: false) ] ] : [])
  end

  private
    # WHY: ordered here because the list had no order of its own: the rows were whatever the database happened to return, which is the same list in a different sequence on a different day.
    def on_tab(events, tab)
      case tab
      when "past" then events.past.order(starts_at: :desc)
      when "to_do" then events.to_do.order(:starts_at)
      when "canceled" then events.canceled.order(starts_at: :desc)
      else events.current_and_upcoming.order(:starts_at)
      end
    end

    def narrow(events)
      events = events.where(category: categories) if categories.any?
      events = events.where(manager: member) if managed?
      events = events.where(id: member.registrations.where(status: answers.flat_map { STATUSES[it] }).select(:event_id)) if answers.any?
      events
    end

    def params_with(scope: self.scope, categories: self.categories, answers: self.answers, managed: managed?)
      { scope:, category: categories, answer: answers, managed: ("1" if managed) }.compact_blank
    end
end
