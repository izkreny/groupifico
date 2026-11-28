module FlashHelper
  # WHY: a notice that links a record arrives as a hash of its text, the link's words and its URL, because the flash crosses the redirect in the JSON session cookie, which drops `html_safe`; the link is built here at render time and the text escaped like any other notice, rather than markup stored in the flash and trusted on the way out.
  def flash_message(message)
    if message.is_a?(Hash)
      text, words, url = message.values_at("text", "link", "url")
      html_escape(text) % { link: link_to(words, url, class: "link") }
    else
      message
    end
  end
end
