class AppFormBuilder < ActionView::Helpers::FormBuilder
  # The error and the hint share one slot because frame 9h of the wireframes draws the hint exactly
  # where frame 9h2 draws the error - same position, same size, differing only in colour - so the
  # two are one line in two states rather than two lines that never coexist.
  def field(attribute, as: :text_field, hint: nil)
    messages = object.errors.full_messages_for(attribute)
    invalid  = messages.any?
    note     = invalid ? messages.to_sentence : hint

    @template.safe_join [
      label(attribute, class: "label"),
      control(as, attribute, invalid: invalid, describedby: (note_id(attribute, invalid) if note.present?)),
      note_tag(note, note_id(attribute, invalid), invalid: invalid)
    ].compact
  end

  private
    # daisyUI's `validator` component is what colours a server-rejected control, and the control
    # carries it unconditionally. Its selector is not only `:user-invalid`, which would need a
    # person to have typed something: it also matches
    # `.validator[aria-invalid]:not([aria-invalid="false"])`, so the `aria-invalid` set below is
    # what drives it, and a sibling `~ .validator-hint` is revealed by the same rule. That is why
    # no `-error` class is composed here for either the control or the note - nothing about the
    # error state is expressed in a class name at all, which also leaves nothing for Tailwind's
    # literal-class-name scanning to miss.
    def control(as, attribute, invalid:, describedby:)
      component = as == :text_area ? "textarea" : "input"

      public_send as, attribute,
        class: [ component, "w-full", "validator" ],
        aria: { invalid: ("true" if invalid), describedby: describedby }.compact
    end

    def note_tag(text, id, invalid:)
      return if text.blank?

      @template.tag.p text, id: id, class: (invalid ? "validator-hint" : "label")
    end

    def note_id(attribute, invalid)
      field_id attribute, invalid ? :error : :hint
    end
end
