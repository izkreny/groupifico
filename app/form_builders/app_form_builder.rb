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

  # One attribute's values as a single control, drawn as daisyUI's `join` of radio buttons. Not a
  # case of `field`'s `as:`: that path draws one `<label for>` naming one control, where a radio
  # group is named by a `<legend>` over a `<fieldset>` and each radio carries its own name. The
  # rest of a field's anatomy is reused rather than reimplemented - the one note slot, the error
  # winning it, and the registration in `drawn` that keeps the message off the summary.
  #
  # The `validator` class goes on the group rather than on a radio, for the reason its stylesheet
  # gives: the rule that reveals `.validator-hint` matches a *preceding sibling*, and no single
  # radio is one. `aria-invalid` stays on the controls, which is where it means something, and
  # daisyUI's `:has()` branch is what carries it up to the group.
  def segmented_field(attribute, choices:, label: nil, hint: nil)
    messages = object.errors.full_messages_for(attribute)
    invalid  = messages.any?

    drawn << attribute
    note    = invalid ? messages.to_sentence : hint
    note_id = field_id(attribute, invalid ? :error : :hint)

    @template.tag.fieldset class: "fieldset" do
      @template.safe_join [
        @template.tag.legend(label || object.class.human_attribute_name(attribute), class: "label"),
        segments(attribute, choices, invalid:, describedby: (note_id if note.present?)),
        note_tag(note, note_id, invalid:)
      ].compact
    end
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
  # cannot show by construction: `errors[:base]`, an attribute a given form draws no control for,
  # and a `belongs_to` presence failure like `Event#group`. Before this existed each of those was
  # rendered by the old full-messages list and then silently vanished.
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

    # `aria-label` on each radio rather than a `<label for>` beside it, which is daisyUI's own
    # syntax for the joined form: the button face *is* the input, so a second element carrying the
    # text would draw the word twice.
    def segments(attribute, choices, invalid:, describedby:)
      @template.tag.div class: [ "join", ("validator" if invalid) ] do
        @template.safe_join(choices.map { |text, value|
          radio_button attribute, value,
            class: "join-item btn",
            aria: { label: text, invalid: ("true" if invalid), describedby: }.compact
        })
      end
    end

    # `whitespace-normal` on the hint because daisyUI's `.label` is `white-space: nowrap`, which is
    # right for the two or three words a label holds and wrong for a sentence: the box stays inside
    # the column while the text runs off the screen, so only `documentElement.scrollWidth` knows.
    # Measured on #245 at 79px past a 390px phone, and again here. The error branch is left alone:
    # `validator-hint` carries no `nowrap`.
    def note_tag(text, id, invalid:)
      return if text.blank?

      @template.tag.p text, id: id, class: (invalid ? "validator-hint" : "label whitespace-normal")
    end

    COMPONENTS = { text_area: "textarea", select: "select" }.freeze
    private_constant :COMPONENTS
end
