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

      expect(html).to include %(<p id="address_name_error" class="label text-error">Name can&#39;t be blank</p>)
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
  end
end
