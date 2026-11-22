module TrimHelper
  # WHY: a class per line count rather than an interpolated `line-clamp-#{lines}`, because Tailwind compiles only class names it finds whole in the source.
  LINE_LIMITS = { 1 => "truncate", 2 => "line-clamp-2" }.freeze

  # WHY: one helper rather than a `truncate` class per view, so a field trims the same way on every screen; a value trims only where its whole is a tap away, in fixed-height chrome or behind a link to a screen that draws it whole, and everything else wraps with `wrap-anywhere`.
  # WHY: the `title` is a desktop pointer's extra and never the way in, since touch and keyboard never show it.
  def trimmed(text, tag_name = :span, lines: 1, **options)
    tag.public_send(tag_name, text, title: text, **options.except(:class), class: class_names(LINE_LIMITS.fetch(lines), options[:class]))
  end
end
