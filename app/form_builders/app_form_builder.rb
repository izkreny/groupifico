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
    # `input-error` and its siblings are what daisyUI colours a server-rejected control with. The
    # `validator` component is not the pattern here: it is driven by the browser's own constraint
    # API, which never sees an error the server found.
    #
    # Both class names are spelled out rather than composed from `component`. Tailwind finds the
    # utilities it compiles by scanning source for literal class names, so an interpolated
    # `"#{component}-error"` reaches the markup and reaches no stylesheet: the control renders
    # carrying a class that paints nothing.
    def control(as, attribute, invalid:, describedby:)
      component, error = as == :text_area ? [ "textarea", "textarea-error" ] : [ "input", "input-error" ]

      public_send as, attribute,
        class: [ component, "w-full", (error if invalid) ],
        aria: { invalid: ("true" if invalid), describedby: describedby }.compact
    end

    def note_tag(text, id, invalid:)
      return if text.blank?

      @template.tag.p text, id: id, class: [ "label", ("text-error" if invalid) ]
    end

    def note_id(attribute, invalid)
      field_id attribute, invalid ? :error : :hint
    end
end
