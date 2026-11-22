module ClipboardHelper
  # WHY: the `clipboard` controller's contract in one place, so a caller names only the text, its noun and any colour swap, and a renamed value or target reaches every copy button at once.
  def clipboard_data(content, noun, idle_class: nil, done_class: nil)
    { controller: "clipboard", clipboard_content_value: content, clipboard_copied_value: "#{noun.capitalize} copied", clipboard_failed_value: "Couldn't copy. Select the #{noun} and copy it yourself.", clipboard_idle_class: idle_class, clipboard_done_class: done_class }.compact
  end

  def clipboard_icon_button(accessible_name)
    tag.button type: "button", class: "btn btn-ghost btn-circle btn-sm flex-none", aria: { label: accessible_name }, data: { clipboard_target: "button", action: "clipboard#copy" } do
      tag.span(icon(:copy, class: "size-icon-control"), class: "contents", data: { clipboard_target: "idle" }) + tag.span(icon(:copied, class: "size-icon-control"), class: "contents", hidden: true, data: { clipboard_target: "done" })
    end
  end

  def clipboard_status
    tag.p class: "text-meta sr-only", role: "status", data: { clipboard_target: "status" }
  end
end
