class AppFormBuilder < ActionView::Helpers::FormBuilder
  # The error and the hint share one slot, because a field shows at most one line under its control
  # and the wireframes put both of them there - frame 9h the hint, frame 9h2 the error. Sizes and
  # spacing come from daisyUI, not from the frames, per the wireframe-fidelity note on #239.
  #
  # `as:` names the field helper that draws the control; `choices:` and `prompt:` reach a `:select`,
  # whose html options sit in a different positional argument than every other helper's.
  def field(attribute, as: :text_field, label: nil, hint: nil, choices: nil, prompt: nil, **options)
    drawn << attribute

    messages = object.errors.full_messages_for(attribute)
    invalid  = messages.any?
    note     = invalid ? messages.to_sentence : hint
    note_id  = field_id(attribute, invalid ? :error : :hint)

    @template.safe_join [
      label(attribute, label, class: "label"),
      control(as, attribute, options, choices:, prompt:, invalid:, describedby: (note_id if note.present?)),
      note_tag(note, note_id, invalid:)
    ].compact
  end

  # Recorded so `shared/_errors` can carry the messages no field drew. A nested form draws its
  # record's own errors, so the association counts as covered: `validates_associated :address`
  # leaves "Address is invalid" on the parent while the address's own fields say what is wrong,
  # and repeating it in the summary would be noise.
  def fields_for(record_name, *, **, &)
    drawn << record_name
    super
  end

  # Every message whose attribute nothing on this form drew, which is what a per-field pattern
  # cannot show by construction: `errors[:base]`, an attribute with no control of its own such as
  # `Group#group_type`, and a `belongs_to` presence failure like `Event#group`. Before this existed
  # each of those was rendered by the old full-messages list and then silently vanished.
  def unattached_error_messages
    object.errors.reject { |error| drawn.include?(error.attribute) }.map(&:full_message)
  end

  private
    def drawn
      @drawn ||= []
    end

    # daisyUI's `validator` component is what colours a server-rejected control, and the control
    # carries it unconditionally. Its selector is not only `:user-invalid`, which would need a
    # person to have typed something: it also matches
    # `.validator[aria-invalid]:not([aria-invalid="false"])`, so the `aria-invalid` set below is
    # what drives it, and a sibling `~ .validator-hint` is revealed by the same rule. That is why
    # no `-error` class is composed here for either the control or the note - nothing about the
    # error state is expressed in a class name at all, which also leaves nothing for Tailwind's
    # literal-class-name scanning to miss.
    #
    # A caller's own `class:` and `aria:` are composed with these rather than replaced by them: an
    # earlier revision merged ours last, which silently dropped whichever of the two a caller had
    # passed.
    def control(as, attribute, options, choices:, prompt:, invalid:, describedby:)
      component  = COMPONENTS.fetch(as, "input")
      html       = options.except(:class, :aria).merge(
        class: [ component, "w-full", "validator", options[:class] ],
        aria: { invalid: ("true" if invalid), describedby: }.compact.merge(options[:aria] || {})
      )

      # `select` takes its html options fourth, after the choices and its own options, so passing
      # them second loses the component class and the aria pair into a hash it ignores.
      if as == :select
        select attribute, choices, { prompt: }.compact, html
      else
        public_send as, attribute, html
      end
    end

    def note_tag(text, id, invalid:)
      return if text.blank?

      @template.tag.p text, id: id, class: (invalid ? "validator-hint" : "label")
    end

    COMPONENTS = { text_area: "textarea", select: "select" }.freeze
    private_constant :COMPONENTS
end
