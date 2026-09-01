module HtmlHelper
  # The visible text of a rendered page, so an assertion reads what a person would actually see
  # rather than matching markup. Matching the raw body would tie the assertion to the tag and the
  # classes around the value, which is exactly what a frontend rewrite changes; parsing survives
  # that and still fails if the value stops being rendered at all.
  def page_text(body)
    Nokogiri::HTML(body).css("body").text.squish
  end
end
