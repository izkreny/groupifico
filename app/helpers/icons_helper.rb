# One Heroicons name per meaning the wireframes' icon legend fixes, so a view names what it means and never a glyph.
module IconsHelper
  # The legend's whole mapping. A meaning absent from here is not an icon this application draws, which is what `fetch` below turns into a failure rather than a blank.
  ICONS = {
    # Event.statuses
    unconfirmed: "question-mark-circle",
    confirmed: "check-circle",
    concluded: "archive-box",
    canceled: "no-symbol",

    # Registration.statuses. `reserved` is drawn only on a plain member's read-only roster; every other screen reads the absence of an answer as the state.
    reserved: "bookmark",
    invited: "paper-airplane",
    yes: "check-circle",
    maybe: "clock",
    no: "x-circle",

    # Facts an event card states.
    when: "calendar",
    where: "map-pin",

    # Actions on a record.
    new: "plus",
    edit: "pencil-square",
    duplicate: "document-duplicate",
    delete: "trash",
    save: "check",
    dismiss: "x-mark",

    # Navigation. Chevrons only - the legend has no arrow glyph.
    back: "chevron-left",
    go_to: "chevron-right",
    disclose: "chevron-down",
    close_panel: "chevron-up",

    # The three tabs. `events` and `when` are the same glyph because the legend gives the calendar both meanings.
    home: "home",
    events: "calendar",
    members: "users",

    # Reaching a person, and reaching the group.
    call: "phone",
    email: "envelope",
    add_member: "user-plus",
    invite_link: "link",

    # States the reader is told about.
    alert: "exclamation-triangle",
    signed_out: "lock-closed",
    resend: "arrow-path"
  }.freeze

  # The one glyph the legend draws heavier than the 2 the initializer sets for everything else.
  BACK_STROKE_WIDTH = "2.5"

  # Draws a legend meaning. Decorative by default, because an icon beside its own label is read twice otherwise; pass `label:` where the icon is the only thing a control says.
  def icon(meaning, label: nil, **options)
    meaning = meaning.to_sym

    options[:stroke_width] ||= BACK_STROKE_WIDTH if meaning == :back

    super(ICONS.fetch(meaning), **accessible_attributes(label), **options)
  end

  # Draws the icon for whatever the record's status is. An unknown status raises through `ICONS.fetch`, because a status nobody mapped is a gap in the legend rather than a row that quietly loses its glyph.
  def status_icon(record, **options)
    icon(record.status, **options)
  end

  private
    def accessible_attributes(label)
      return { aria_hidden: "true" } if label.blank?

      { aria_hidden: "false", role: "img", aria_label: label }
    end
end
