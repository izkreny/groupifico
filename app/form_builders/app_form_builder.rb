class AppFormBuilder < ActionView::Helpers::FormBuilder
  # The error and the hint share one slot, because a field shows at most one line under its control
  # and the wireframes put both of them there - frame 9h the hint, frame 9h2 the error. Sizes and
  # spacing come from daisyUI, not from the frames, per the wireframe-fidelity note on #239.
  #
  # `as:` names the field helper that draws the control; `choices:` and `prompt:` reach a `:select`,
  # whose html options sit in a different positional argument than every other helper's.
  def field(attribute, as: :text_field, label: nil, hint: nil, choices: nil, prompt: nil, **options)
    absent   = absent_association(attribute)
    messages = object.errors.full_messages_for(attribute) + absence_messages(absent)
    invalid  = messages.any?

    drawn << attribute
    drawn << absent if absent
    note     = invalid ? messages.to_sentence : hint
    note_id  = field_id(attribute, invalid ? :error : :hint)

    @template.safe_join [
      label(attribute, label, class: "label"),
      control(as, attribute, options, choices:, prompt:, invalid:, describedby: (note_id if note.present?)),
      note_tag(note, note_id, invalid:)
    ].compact
  end

  # The summary reads what the fields drew, so the fields have to render first and appear second.
  # That ordering is the whole reason this method exists rather than each template capturing its
  # own fieldset: eight templates each holding the invariant is eight chances to flatten it back to
  # the obvious order, which empties `drawn` and repeats every field error in the summary.
  #
  # Named for what it adds rather than for what it wraps, because `fields` is Rails' own method on
  # `FormBuilder` and this builder is installed application-wide.
  def with_error_summary(&)
    captured = @template.capture(&)

    @template.safe_join [ @template.render("shared/errors", form: self), captured ]
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
    object.errors.reject { covered? it.attribute }.map(&:full_message)
  end

  private
    def drawn
      @drawn ||= []
    end

    # `accepts_nested_attributes_for` copies each child error onto the parent under a compound key,
    # `:"address.name"`, so an exact match against `drawn` classes a message the nested field has
    # already drawn as unattached and repeats it in the summary. The association's name is the part
    # that says who drew it, and a plain attribute has no `.` to split on.
    def covered?(attribute)
      drawn.include? attribute.to_s.split(".").first.to_sym
    end

    # A missing `belongs_to` is keyed on the association, never on its foreign key, so a control
    # drawn for `:member_id` answers for `:member` too. Without this a missing `Registration#member`
    # renders in the summary while the select it belongs to sits unmarked, which is the case
    # `RegistrationsController#new_registration_params` lets through on purpose so the model can
    # refuse it.
    #
    # It answers for the association's *absence* alone. `validates_associated` files its failure on
    # the same key with type `:invalid`, and that one belongs to the nested form's own fields, which
    # say which of the child's attributes is wrong; claiming it here marks a select the reader
    # deliberately left on its prompt and puts "Address is invalid" under it. Measured on `Event`:
    # a missing `belongs_to` is `:blank`, an association failing its own validations is `:invalid`.
    def absent_association(attribute)
      association = attribute.to_s.delete_suffix("_id")
      return if association == attribute.to_s

      association.to_sym if object.errors.where(association.to_sym, :blank).any?
    end

    def absence_messages(association)
      return [] unless association

      object.errors.where(association, :blank).map(&:full_message)
    end

    # daisyUI's `validator` component is what colours a server-rejected control, and it is applied
    # only to a control the server rejected. Its selector matches
    # `.validator[aria-invalid]:not([aria-invalid="false"])`, which is the server-rendered case and
    # the reason the component works here at all; a sibling `~ .validator-hint` is revealed by the
    # same rule.
    #
    # The same rule set also carries `:user-valid` and `:user-invalid`, so applying the class
    # unconditionally switched on the browser's own constraint colouring across every form: a valid
    # field turned success-green once touched, and a blurred empty `required` field turned
    # error-red carrying no message at all. That second state is worse than no colour, so the class
    # is conditional. Decided by the owner on 2026-09-10; default daisyUI governs styling *values*
    # rather than obliging every behaviour a component can be made to do.
    #
    # A caller's own `class:` and `aria:` are composed with these rather than replaced by them: an
    # earlier revision merged ours last, which silently dropped whichever of the two a caller had
    # passed.
    def control(as, attribute, options, choices:, prompt:, invalid:, describedby:)
      component  = COMPONENTS.fetch(as, "input")
      html       = options.except(:class, :aria).merge(
        class: [ component, "w-full", ("validator" if invalid), options[:class] ],
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
