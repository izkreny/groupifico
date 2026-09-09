> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Show field errors under inputs

Implementation plan for [#239](https://github.com/izkreny/groupifico/issues/239). The issue holds the acceptance criteria; this answers how.

## Approach

One `AppFormBuilder < ActionView::Helpers::FormBuilder` in `app/form_builders/`, exposing a single `field` method that draws a label, an input, and one slot beneath the input. The slot holds the attribute's error when it has one and the field's hint when it does not, because frame 9h renders the hint in exactly the position frame 9h2 renders the error, in the same size and weight, with only the colour differing. Two lines never appear at once, so the slot is one element rather than two.

Every form already renders `shared/_errors` above its fieldset, so that partial is where the summary alert lands, and each of the eight forms picks it up without being edited. The address fields partial is the one field consumer this issue converts; the group, event, member, registration and account rows convert their own fields in their own issues.

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

- [ ] `bin/ci`

What those gates cannot see: whether the field matches frame 9h2 as drawn. The error's position, size and colour against the wireframe is the owner's judgement on the rendered screen, and the same holds for the summary alert reading as the same component the flash uses. `be_accessible` proves the input and its message are associated and labelled; it says nothing about whether they look like the frame.

The accessibility and paint assertions are watched failing before the fix, on the pre-change markup, per the repository's testing conventions.

## Open questions

- The summary alert in frame 9h2 carries a warning triangle. The icon helper arrives with #238, which is not a blocker of this issue, so the alert ships text-only here. Should #238 add the icon when it lands, or should this issue wait for it?
- Until each form row converts its own fields, a form whose *own* attribute fails validation shows the summary alert with nothing highlighted, because the per-message list is gone and only the address subfields render inline errors. Options: convert the remaining seven forms' fields here, widening this diff into files #248, #249, #252, #253 and #255 own; or accept the interim state, which the epic's decomposition already implies.

## Settled

None yet.
