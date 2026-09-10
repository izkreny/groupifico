> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Show field errors under inputs

Implementation plan for [#239](https://github.com/izkreny/groupifico/issues/239). The issue holds the acceptance criteria; this answers how.

## Approach

One `AppFormBuilder < ActionView::Helpers::FormBuilder` in `app/form_builders/`, exposing a single `field` method that draws a label, a control, and one slot beneath the control. The slot holds the attribute's error when it has one and the field's hint when it does not, because a field shows at most one line there and the wireframes put both in that position - frame 9h the hint, frame 9h2 the error.

`shared/_errors` above the fieldset is the summary alert, and every one of the eight forms draws its fields through the builder.

## What Rails already provides, and what has to be turned off

`ActionView::Helpers::FormBuilder` exposes `object`, `field_id` and `field_name` publicly, so the builder reads `object.errors[attribute]` directly and derives every id through `field_id(attribute, :error)` rather than composing strings. That is also the accessible-association pattern Rails documents on `field_id` itself: `aria: { describedby: f.field_id(:title, :error) }` on the input against a matching `id:` on the error element.

`ActionView::Base.field_error_proc` has to be neutralised. Its default is

```ruby
Proc.new { |html_tag, instance| content_tag :div, html_tag, class: "field_with_errors" }
```

and `ActiveModelInstanceTag` routes the label and the input through it *separately*, so an invalid attribute today yields two `div.field_with_errors` wrappers, one around the label and one around the input. That breaks the field's own vertical layout and marks invalidity a second time, less accessibly, than the builder does. An initializer sets it to return its tag untouched.

`default_form_builder AppFormBuilder` in `ApplicationController` is the `ActionController::FormBuilder` macro, which takes the class and stores it in a `class_attribute`. Every `form_with` in the application picks it up, nested `fields_for` builders included, with no per-form `builder:` option.

## Markup lives in the builder, not in a partial

The field's three tags are built with the template's own tag helpers inside the builder, rather than by rendering a per-field partial. One render call per field on a nine-field address form is a cost with nothing to show for it, and the markup is short enough that a second file would hide it rather than clarify it. The acceptance criterion about strict locals is then satisfied by there being no partial to declare them on.

## Steps

- Add `app/form_builders/app_form_builder.rb` with `field(attribute, as: :text_field, hint: nil, **options)`: label in the small muted style above the input, the input rendered by the named field helper, and the error-or-hint slot under it. An invalid input carries `aria-invalid="true"`, the error class, and `aria-describedby` pointing at `field_id(attribute, :error)`; a field with a hint and no error points at `field_id(attribute, :hint)`.
- Compose the field's daisyUI markup through the daisyUI Blueprint MCP server, loading the `daisyui-blueprint-mcp` skill first, per the epic: setup expert, rules enforcer, component syntax expert for every component used, then the quality inspector over the change.
- Add `config/initializers/form_errors.rb` setting `config.action_view.field_error_proc` to return its tag unchanged, with a comment saying which wrapper it suppresses and why the builder replaces it.
- Set `default_form_builder AppFormBuilder` in `ApplicationController`.
- Rewrite `app/views/shared/_errors.html.erb` as the summary alert: the alert component `layouts/_flash` already uses, reading `Please fix the highlighted fields.`, rendered only when the object has errors, with the full-message list removed.
- Convert `app/views/addresses/_form_fields.html.erb` to `form.field`, keeping every attribute's Rails-default id and name so the request specs that assert `event_address_attributes_name` keep passing.
- Add `spec/system/form_errors_spec.rb` covering the pattern on the address edit screen as its host: the error paints under its input, the input is marked invalid, the summary alert paints, the submitted value survives the failed save, and the page has no accessibility violations.

## Verification

- `bin/ci`

What those gates cannot see: whether the field reads well on the rendered screen. Its position, size and colour are daisyUI's defaults and are not judged against a frame, per the `## Wireframe fidelity` note on the issue, so what is left for the owner is whether the copy and the states are right. `be_accessible` proves the input and its message are associated and labelled; it says nothing about how they read.

The accessibility and paint assertions are watched failing before the fix, on the pre-change markup, per the repository's testing conventions.

## Open questions

- The summary alert in frame 9h2 carries a warning triangle. The icon helper arrives with #238, which is not a blocker of this issue, so the alert ships text-only here. Should #238 add the icon when it lands, or should this issue wait for it?

## Settled

**Do the wireframes settle styling?** No. They settle what a screen contains, what it says and how it behaves; every size, gap, weight and colour comes from default daisyUI, and nothing is overridden to match a frame. Decided by the owner on 2026-09-09 for the whole beta milestone, and recorded on every redesign issue as `## Wireframe fidelity`.

**Which daisyUI component renders a server-rejected field?** `validator` and `validator-hint`, unmodified. Its selector carries `.validator[aria-invalid]:not([aria-invalid="false"])` alongside `:user-invalid`, so the `aria-invalid` the builder already set for accessibility drives it, and no `-error` class is composed anywhere.

**Which controls carry the `validator` class?** Only a control the server rejected. The same rule set also carries `:user-valid` and `:user-invalid`, so applying it everywhere switched on the browser's own constraint colouring: a valid field turned success-green once touched, and a blurred empty `required` field turned error-red carrying no message. Decided by the owner on 2026-09-10, answering RF11; default daisyUI governs styling values rather than obliging every behaviour a component can be made to do.

**Do the remaining seven forms convert here, or wait for their own issues?** Here. Leaving them was a regression: their own attributes' errors had no surface at all once the full-messages list was gone. Decided by the owner on 2026-09-09, answering RF1.

**What shows an error that has no field?** The summary alert. A per-field pattern cannot render `errors[:base]`, or `Group#group_type`, which has no control by design - so the builder records what it drew and the summary carries the rest.
