module ClipboardHelper
  # WHY: the `clipboard` controller's values and status line in one place, so a caller names only the text, its noun and any colour swap; the join link's labelled button still wires its own `button`, `idle` and `done` targets, so renaming one of those means editing `groups/_join_link` as well.
  def clipboard_data(content, noun, idle_class: nil, done_class: nil)
    { controller: "clipboard", clipboard_content_value: content, clipboard_copied_value: "#{noun.capitalize} copied", clipboard_failed_value: "Couldn't copy. Select the #{noun} and copy it yourself.", clipboard_idle_class: idle_class, clipboard_done_class: done_class }.compact
  end

  def clipboard_icon_button(accessible_name)
    tag.button type: "button", class: "btn btn-ghost btn-circle btn-sm flex-none ms-text-control me-controls", aria: { label: accessible_name }, data: { clipboard_target: "button", action: "clipboard#copy" } do
      tag.span(icon(:copy, class: "size-icon-inline"), class: "contents", data: { clipboard_target: "idle" }) + tag.span(icon(:copied, class: "size-icon-inline"), class: "contents", hidden: true, data: { clipboard_target: "done" })
    end
  end

  def clipboard_status
    tag.p class: "text-meta sr-only", role: "status", data: { clipboard_target: "status" }
  end
end
