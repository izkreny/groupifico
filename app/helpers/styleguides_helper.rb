module StyleguidesHelper
  # Where the themes are defined, read rather than copied, so the styleguide's swatches cannot drift from the palette the app paints.
  THEMES_STYLESHEET = Rails.root.join("app/assets/tailwind/application.css")

  # Where the app draws each legend meaning, for the legend table. Kept by hand, so a meaning added to `IconsHelper::ICONS` fails the page until it is described here, while one that moves screens is not caught.
  ICON_USES = {
    unconfirmed: "An event's status: the Status choice on the event form, the event's row on the events list, and the status line on the event screen.",
    confirmed: "An event's status: the Status choice on the event form, the event's row on the events list, the status line on the event screen, and the next-up card on Home and the events list.",
    concluded: "An event's status: the Status choice on the event form, the event's row on the events list, and the status line on the event screen.",
    canceled: "An event's status: the Status choice on the event form, the event's row on the events list, and the status line on the event screen.",
    reserved: "A registration nobody has asked yet: the badge beside a name on the event's roster, for a reader who cannot ask, Reserve a place for everyone under the roster, and the reserved count in the tally on the next-up card and the event screen.",
    response_requested: "A registration asked but unanswered: the ask button and badge on a roster row, Ask the rest and Ask everyone, and the no-reply count.",
    yes: "An answer: the reply button and badge on a roster row, its count in Who's coming and on the next-up card, and the reader's own answer on the events list.",
    maybe: "An answer: the reply button and badge on a roster row, its count in Who's coming and on the next-up card, and the reader's own answer on the events list.",
    no: "An answer: the reply button and badge on a roster row, its count in Who's coming and on the next-up card, and the reader's own answer on the events list.",
    when: "When an event happens: the time line on the next-up card and on the event screen.",
    where: "Where an event happens: the address line on the next-up card and on the event screen.",
    new: "Creating a record: New on the events list, New event on an empty Home, New group, Invite on the members list, and Create group on the account screen.",
    edit: "Editing a record: the group's name in the header, the event screen, a member's row and screen, the address on the group form, and Correct on the address screen.",
    duplicate: "Copying an event: Duplicate on the event screen.",
    delete: "Removing a registration, an event, a group, a member or an account: Delete or Remove first in an edit form's button row, Delete my account, and the primary on every confirm sheet.",
    save: "Saving a form: its submit button, such as Save changes, Create event, Update the list or Send invite.",
    cancel: "Leaving without a change: Cancel in every form's button row, and the keep button on every confirm sheet.",
    dismiss: "Dismissing a flash notice or alert: the x at its end.",
    confirm: "Spending an emailed link: the button on the sign-in link and sign-up confirmation pages.",
    back: "Going back: the Back link in the header of a pushed screen.",
    go_to: "Going further: See all events on Home, and the name, mobile and email row on the account screen.",
    disclose: "Opening the group switcher in the header.",
    close_panel: "Closing the group switcher in the header.",
    home: "The Home tab, in the header and in the bottom dock.",
    events: "The Events tab, in the header and in the bottom dock.",
    members: "The Members tab, in the header and in the bottom dock, the credits line on the event screen, and the Responses line on the next-up card and the event screen.",
    call: "Calling a member: their row on the members list and the Mobile row on their screen.",
    email: "Emailing a member: their row on the members list and the Email row on their screen. Asking for an emailed link: the button on the sign-in and create-a-group forms.",
    add_member: "Not drawn yet: the legend's adding of a person.",
    send_invite: "Bringing someone into the group: Send invite on the new member form.",
    invite_link: "Not drawn yet: the legend's link for joining the group.",
    success: "A success alert: the flash notice after an action.",
    info: "An info alert: the note atop the duplicate screen saying what the copy changed.",
    warning: "Not drawn yet: the legend's warning alert.",
    error: "An error alert: the flash alert, the error summary atop a form, and the block on the account-deletion sheet.",
    signed_out: "Not drawn yet: the legend's signed-out state.",
    resend: "Not drawn yet: the legend's resend action."
  }.freeze

  # The named theme's daisyUI colour tokens, name to hex, in the order the stylesheet lists them.
  def theme_colours(theme)
    THEMES_STYLESHEET.read[/name: "#{Regexp.escape(theme)}";(.*?)\}/m, 1].scan(/--color-([a-z0-9-]+): (#\h{6});/).to_h
  end

  # The app's own colour tokens, name to value, from the stylesheet's `@theme inline` block: mixes of daisyUI's colours rather than colours of their own, so they follow every theme.
  def app_colours
    THEMES_STYLESHEET.read[/@theme inline \{(.*?)\}/m, 1].scan(/--color-([a-z0-9-]+): ([^;]+);/).to_h
  end

  # The colour an app token's mix lands on over the named theme's page, so its row can print a hex and measure contrast as daisyUI's rows do. Mixed per channel in sRGB, where the browser mixes in oklab, which is close enough to read a ratio off.
  def app_colour_hex(theme, value)
    token, share = value.match(/var\(--color-([a-z0-9-]+)\) (\d+)%/).captures
    colours = theme_colours(theme)
    ink, page = [ colours.fetch(token), colours.fetch("base-100") ].map { it.delete_prefix("#").scan(/../).map(&:hex) }

    "#" + ink.zip(page).map { |over, under| format("%02x", (over * share.to_f / 100 + under * (1 - share.to_f / 100)).round) }.join
  end

  # The WCAG 2 contrast ratio of two hex colours, from 1 to 21, whichever is lighter.
  def contrast_ratio(one, other)
    lighter, darker = [ one, other ].map { relative_luminance(it) }.sort.reverse

    (lighter + 0.05) / (darker + 0.05)
  end

  # A contrast ratio as the theme was settled on it, tagged where it misses WCAG AA for text: a warning from 3:1, which still clears large text and interface chrome, and an error below. Untagged for a surface, per `surface?`, which is not read against anything.
  def contrast_ratio_tag(ratio, token: nil)
    text = "#{number_with_precision ratio, precision: 2}:1"

    if surface?(token) || ratio >= 4.5
      tag.span(text)
    elsif ratio >= 3
      tag.span(text, class: "badge badge-xs badge-warning")
    else
      tag.span(text, class: "badge badge-xs badge-error")
    end
  end

  # Whether a token is a surface rather than a colour read on one. The base content is the body text, so it is not.
  def surface?(name)
    name.in?(%w[ base-100 base-200 base-300 ])
  end

  # The token a colour is read against: each colour against its content colour and back, each base against the base content, and the base content against the page.
  def contrast_pair(name)
    case name
    when "base-content" then "base-100"
    when /\Abase-/      then "base-content"
    when /-content\z/   then name.delete_suffix("-content")
    else                     "#{name}-content"
    end
  end

  # The member switcher's options: each member's name, then their role tags as the member row draws them, then their status.
  def member_switch_choices(members)
    members.map do |member|
      tags = member.role_names.map { role_tag it } << member.status

      [ "#{member.full_name} - #{tags.join(", ")}", member.id ]
    end
  end

  private
    def relative_luminance(hex)
      red, green, blue = hex.delete_prefix("#").scan(/../).map { linear(it.to_i(16) / 255.0) }

      0.2126 * red + 0.7152 * green + 0.0722 * blue
    end

    def linear(channel)
      channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4
    end
end
