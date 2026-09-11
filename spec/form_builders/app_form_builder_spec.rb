require "rails_helper"

# The builder is a plain object rendering markup, so it is asserted directly rather than through a
# screen. Two of the behaviours here reach no screen at all: no view passes `hint:` yet, and the
# suppressed `field_with_errors` wrapper is an absence, which a screen spec can only assert by
# proxy.
RSpec.describe AppFormBuilder do
  # `form_with` is what installs the builder in production, so the fields are drawn through it here
  # too rather than by constructing the builder with a hand-made template.
  def field_for(record, attribute, **options)
    view = ApplicationController.new.tap { it.request = ActionDispatch::TestRequest.create }.view_context

    view.form_with(model: record, url: "/x") { |form| form.field(attribute, **options) }
  end

  # The builder itself rather than what it rendered, for the assertions about what it recorded.
  def builder_for(record)
    view = ApplicationController.new.tap { it.request = ActionDispatch::TestRequest.create }.view_context
    captured = nil
    view.form_with(model: record, url: "/x") { |form| captured = form and nil }

    captured
  end

  describe "#field" do
    it "renders the hint under the input when the attribute has no errors" do
      html = field_for(build(:address), :name, hint: "Optional. Shown to members of your groups.")

      expect(html).to include %(<p id="address_name_hint" class="label whitespace-normal">Optional. Shown to members of your groups.</p>)
    end

    it "points the input at the hint it rendered" do
      html = field_for(build(:address), :name, hint: "Optional.")

      expect(html).to include %(aria-describedby="address_name_hint")
    end

    it "renders no note at all when the attribute has neither error nor hint" do
      html = field_for(build(:address), :name)

      expect(html).not_to include "address_name_hint"
    end

    it "replaces the hint with the error when the attribute has one" do
      address = build(:address, name: nil)
      address.valid?

      html = field_for(address, :name, hint: "Optional.")

      expect(Nokogiri::HTML(html).at_css("p.validator-hint").text).to eq "Name can't be blank"
      expect(html).not_to include "Optional."
    end

    # `config/initializers/form_errors.rb` is the only thing standing between this and Rails'
    # default, which wraps the label and the input in a `div.field_with_errors` each - two wrappers
    # inside the field's own vertical layout, marking invalidity where no screen reader looks.
    it "wraps neither the label nor the input for an invalid attribute" do
      address = build(:address, name: nil)
      address.valid?

      expect(field_for(address, :name)).not_to include "field_with_errors"
    end

    # RF2 removed `**options` as a speculative parameter, which was right while no caller passed
    # anything. Converting the forms created the callers - `sign_ups/new` passes `required`,
    # `autofocus`, `placeholder` and `autocomplete` - so it is back, with the defect RF2 actually
    # named fixed: the earlier revision merged its own options last and dropped a caller's.
    it "composes a caller's class with its own rather than replacing it" do
      address = build(:address, name: nil)
      address.valid?

      html = field_for(address, :name, class: "h-24")

      expect(Nokogiri::HTML(html).at_css("input")["class"].split).to include "input", "validator", "h-24"
    end

    # `validator` also drives daisyUI's `:user-valid`/`:user-invalid` colouring, so a control the
    # server did not reject must not carry it.
    it "leaves the validator class off a control the server accepted" do
      html = field_for(build(:address), :name)

      expect(Nokogiri::HTML(html).at_css("input")["class"].split).not_to include "validator"
    end

    it "keeps its own aria-describedby when the caller passes an aria hash" do
      input = Nokogiri::HTML(field_for(build(:address), :name, hint: "Optional.", aria: { label: "Venue" })).at_css("input")

      expect(input["aria-describedby"]).to eq "address_name_hint"
      expect(input["aria-label"]).to eq "Venue"
    end

    it "passes a caller's own attributes through to the control" do
      input = Nokogiri::HTML(field_for(build(:address), :name, required: true, placeholder: "Venue")).at_css("input")

      expect(input["required"]).to eq "required"
      expect(input["placeholder"]).to eq "Venue"
    end

    it "labels the field with the caller's text when one is given" do
      html = field_for(build(:address), :name, label: "Venue name")

      expect(Nokogiri::HTML(html).at_css("label[for='address_name']").text).to eq "Venue name"
    end

    # `select` takes its html options in a fourth positional argument, after the choices and its
    # own options, so passing them second loses the component class and the aria pair into a hash
    # it ignores: green markup with no error styling and no accessible association.
    it "puts the component class and the aria pair on a select" do
      address = build(:address, name: nil)
      address.valid?

      select = Nokogiri::HTML(field_for(address, :name, as: :select, choices: %w[ Hall Studio ])).at_css("select")

      expect(select["class"].split).to include "select", "validator"
      expect(select["aria-invalid"]).to eq "true"
      expect(select["aria-describedby"]).to eq "address_name_error"
    end

    # `#unattached_error_messages`'s "treats a foreign-key field as covering its association's
    # error" is the summary half of this rule, and this is the half the reader sees. Without it, a
    # `drawn` entry with no marked control leaves the summary saying "Please fix the highlighted
    # fields." with nothing highlighted, which is worse than the state the rule replaced.
    it "marks the foreign-key control the association's error refers to" do
      registration = Registration.new
      registration.valid?

      html   = field_for(registration, :member_id, as: :select, choices: [])
      select = Nokogiri::HTML(html).at_css("select")

      expect(select["class"].split).to include "validator"
      expect(select["aria-invalid"]).to eq "true"
      expect(select["aria-describedby"]).to eq "registration_member_id_error"
      expect(Nokogiri::HTML(html).at_css("p#registration_member_id_error").text).to eq "Member must exist"
    end

    # `validates_associated` files its failure on the same key with type `:invalid`, and the nested
    # form's own fields say which of the child's attributes is wrong. A foreign-key select claiming
    # that message marks a control the reader deliberately left on its prompt, and the events form
    # renders both that select and the nested fieldset at once.
    it "leaves an association's own validation failure to the fields that own it" do
      event = Event.new(name: "Rehearsal", group: Group.new(name: "Choir", group_type: "choir"), address: Address.new)
      event.valid?

      select = Nokogiri::HTML(field_for(event, :address_id, as: :select, choices: [])).at_css("select")

      expect(event.errors.where(:address, :invalid)).to be_present
      expect(select["class"].split).not_to include "validator"
      expect(select["aria-invalid"]).to be_nil
    end
  end

  describe "#segmented_field" do
    def segmented_for(record, attribute, **options)
      view = ApplicationController.new.tap { it.request = ActionDispatch::TestRequest.create }.view_context

      view.form_with(model: record, url: "/x") { |form| form.segmented_field(attribute, **options) }
    end

    it "names the group with a legend rather than labelling any one radio" do
      html = segmented_for(Group.new, :group_type, choices: [ [ "Choir", "choir" ] ], label: "Type")

      expect(html).to include %(<legend class="label">Type</legend>)
      expect(html).not_to include "<label"
    end

    # The button face is the input, so the word has to reach the accessibility tree through the
    # control itself. Without it the segment is a nameless radio.
    it "names each radio with the choice it stands for" do
      html = segmented_for(Group.new, :group_type, choices: [ [ "Choir", "choir" ], [ "Band", "band" ] ], label: "Type")
      radios = Nokogiri::HTML5.fragment(html).css("input[type=radio]")

      expect(radios.map { it["aria-label"] }).to eq [ "Choir", "Band" ]
      expect(radios.map { it["value"] }).to eq [ "choir", "band" ]
    end

    it "checks the radio the record already answers with" do
      html = segmented_for(Group.new(group_type: "band"), :group_type, choices: [ [ "Choir", "choir" ], [ "Band", "band" ] ])
      checked = Nokogiri::HTML5.fragment(html).css("input[type=radio][checked]")

      expect(checked.map { it["value"] }).to eq [ "band" ]
    end

    it "renders the hint under the group when the attribute has no errors" do
      html = segmented_for(Group.new, :group_type, choices: [ [ "Choir", "choir" ] ], hint: "Changeable later.")

      expect(html).to include %(<p id="group_group_type_hint" class="label whitespace-normal">Changeable later.</p>)
    end

    # The reveal rule matches a preceding sibling, and a single radio is not one, so the class has
    # to sit on the group while the attribute stays on the controls.
    it "marks the group invalid and the radios with it, and replaces the hint with the message" do
      group = Group.new(name: "Choir")
      group.group_type = "orchestra"
      group.valid?

      html = segmented_for(group, :group_type, choices: [ [ "Choir", "choir" ] ], hint: "Changeable later.")
      fragment = Nokogiri::HTML5.fragment(html)

      expect(fragment.at_css("div.join")["class"]).to include "validator"
      expect(fragment.at_css("input[type=radio]")["aria-invalid"]).to eq "true"
      expect(fragment.at_css("input[type=radio]")["aria-describedby"]).to eq "group_group_type_error"
      expect(html).to include %(<p id="group_group_type_error" class="validator-hint">Group type is not included in the list</p>)
    end

    it "keeps the message off the summary, because the group is a control that drew it" do
      group = Group.new(name: "Choir")
      group.group_type = "orchestra"
      group.valid?
      form = builder_for(group)

      form.segmented_field :group_type, choices: [ [ "Choir", "choir" ] ]

      expect(form.unattached_error_messages).not_to include "Group type is not included in the list"
    end
  end

  describe "#unattached_error_messages" do
    it "carries a message whose attribute no field drew" do
      group = Group.new(name: "Choir")
      group.group_type = "orchestra"
      group.valid?
      form = builder_for(group)

      form.field :name

      expect(form.unattached_error_messages).to include "Group type is not included in the list"
    end

    it "leaves out a message whose field was drawn" do
      group = Group.new
      group.valid?
      form = builder_for(group)

      form.field :name

      expect(form.unattached_error_messages).not_to include "Name can't be blank"
    end

    # `validates_associated` leaves "Address is invalid" on the parent while the address's own
    # fields say what is actually wrong, so a nested form counts as covering its association.
    # `accepts_nested_attributes_for` adds a second key for the same failure, `:"address.name"`,
    # which the nested field has already drawn: measured on this record, the parent's error keys are
    # `[:"address.name", :address]`.
    it "treats a nested form as covering its association" do
      group = Group.new(name: "Choir", address: Address.new)
      group.valid?
      form = builder_for(group)

      form.fields_for(:address) { |nested| nested.field :name }

      expect(form.unattached_error_messages).not_to include "Address is invalid"
      expect(form.unattached_error_messages).not_to include "Address name can't be blank"
    end

    it "carries a base error, which can never have a field of its own" do
      group = Group.new(name: "Choir")
      group.errors.add(:base, "Something is off")

      expect(builder_for(group).unattached_error_messages).to eq [ "Something is off" ]
    end

    # A `belongs_to` failure is keyed on the association, so a control drawn for the foreign key
    # answers for it: without this the message goes to the summary while the select it refers to
    # sits unmarked on the page.
    it "treats a foreign-key field as covering its association's error" do
      registration = Registration.new
      registration.valid?
      form = builder_for(registration)

      form.field :member_id, as: :select, choices: []

      expect(registration.errors[:member]).to be_present
      expect(form.unattached_error_messages).not_to include "Member must exist"
    end
  end

  # `fields` is Rails' own, `fields(scope = nil, model: nil, **options)`, and this builder is
  # installed application-wide by `default_form_builder`, so a method of that name here takes the
  # framework's version out of every template in the application. Nothing in the diff would say so:
  # the call raises `ArgumentError` at render time and only in the template that made it. The name
  # is `address_attributes` rather than `address` because `Group` accepts nested attributes for it,
  # which is Rails' own routing of the scope and part of what has to survive.
  describe "#fields" do
    it "leaves Rails' own scoped-fields call reachable" do
      view = ApplicationController.new.tap { it.request = ActionDispatch::TestRequest.create }.view_context

      html = view.form_with(model: Group.new(address: Address.new), url: "/groups") { |form| form.fields(:address) { |nested| nested.text_field :name } }

      expect(html).to include %(name="group[address_attributes][name]")
    end
  end
end
