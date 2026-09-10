require "rails_helper"

# The builder is a plain object rendering markup, so it is asserted directly rather than through a
# screen. Two of the behaviours here reach no screen at all: no view passes `hint:` yet, and the
# suppressed `field_with_errors` wrapper is an absence, which a screen spec can only assert by
# proxy.
RSpec.describe AppFormBuilder do
  # `form_with` is what installs the builder in production, so the fields are drawn through it here
  # too rather than by constructing the builder with a hand-made template.
  def field_for(address, attribute, **options)
    view = ApplicationController.new.tap { it.request = ActionDispatch::TestRequest.create }.view_context

    view.form_with(model: address, url: "/addresses/1") { |form| form.field(attribute, **options) }
  end

  describe "#field" do
    it "renders the hint under the input when the attribute has no errors" do
      html = field_for(build(:address), :name, hint: "Optional. Shown to members of your groups.")

      expect(html).to include %(<p id="address_name_hint" class="label">Optional. Shown to members of your groups.</p>)
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
  end

  describe "#unattached_error_messages" do
    def builder_for(record)
      view = ApplicationController.new.tap { it.request = ActionDispatch::TestRequest.create }.view_context
      captured = nil
      view.form_with(model: record, url: "/x") { |form| captured = form and nil }

      captured
    end

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
    it "treats a nested form as covering its association" do
      group = Group.new(name: "Choir", address: Address.new)
      group.valid?
      form = builder_for(group)

      form.fields_for(:address) { |nested| nested.field :name }

      expect(form.unattached_error_messages).not_to include "Address is invalid"
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
end
