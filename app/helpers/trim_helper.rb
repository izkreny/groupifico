module TrimHelper
  # WHY: one helper rather than a `truncate` class per view, so a field trims the same way on every screen; only fixed-height chrome trims, and everything else wraps with `wrap-anywhere`.
  def trimmed(text, tag_name = :span, **options)
    tag.public_send(tag_name, text, **options.except(:class), class: class_names("truncate", options[:class]))
  end
end
