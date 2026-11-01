# One Heroicons name per meaning the wireframes' icon legend fixes, so a view names what it means and never a glyph.
module IconsHelper
  # The legend's whole mapping. A meaning absent from here is not an icon this application draws, which is what `fetch` below turns into a failure rather than a blank.
  ICONS = {
    # Event.statuses
    unconfirmed: "question-mark-circle",
    confirmed: "check-badge",
    concluded: "shield-check",
    canceled: "no-symbol",

    # Registration.statuses
    reserved: "bookmark",
    invited: "paper-airplane",
    yes: "check-circle",
    maybe: "clock",
    no: "minus-circle",

    # Facts an event card states.
    when: "calendar",
    where: "map-pin",

    # Actions on a record.
    new: "plus",
    edit: "pencil-square",
    duplicate: "document-duplicate",
    delete: "trash",
    save: "check",
    cancel: "x-mark",
    dismiss: "x-mark",

    # The emailed-link pages' one button, which spends the link. The same glyph as `save` because frames 10a and 10b draw the check on it.
    confirm: "check",

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

    # States the reader is told about. The four alert kinds are named as daisyUI names them, so `shared/_alert` draws the kind it colours.
    success: "check-circle",
    info: "information-circle",
    warning: "exclamation-triangle",
    error: "no-symbol",
    signed_out: "lock-closed",
    resend: "arrow-path"
  }.freeze

  # Heroicons' filled set for each size class the app draws: solid, mini and micro are drawn on their own 24, 20 and 16px grids, where its outline set exists at 24px alone.
  VARIANTS = {
    "size-icon-standalone" => "solid", "size-icon-control" => "mini", "size-icon-inline" => "micro",
    "size-6" => "solid", "size-5" => "mini", "size-4" => "micro"
  }.freeze

  # Draws a legend meaning. Decorative by default, because an icon beside its own label is read twice otherwise; pass `label:` where the icon is the only thing a control says.
  #
  # The size class picks the drawing, so a call without one of `VARIANTS`' sizes raises rather than drawing a glyph at a size it was not made for.
  def icon(meaning, label: nil, **options)
    variant = VARIANTS.values_at(*options[:class].to_s.split).compact.first or
      raise ArgumentError, "icon #{meaning.inspect} needs one of #{VARIANTS.keys.join(", ")} in its class"

    super(ICONS.fetch(meaning.to_sym), variant:, **accessible_attributes(label), **options)
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
