Rails.application.config.action_view.field_error_proc = ->(html_tag, _instance) { html_tag }

# Rails wraps every tag belonging to an invalid attribute in `<div class="field_with_errors">`, and
# `ActiveModelInstanceTag` routes the label and the control through that proc separately, so one
# rejected attribute yields two wrappers. Both sit inside the field's own vertical layout and break
# it, and neither is what marks the control invalid: `AppFormBuilder#field` does that with
# `aria-invalid` and `aria-describedby`, which a screen reader can read and a wrapper div cannot,
# and daisyUI's `validator` component reads that same `aria-invalid` for the colour. `validator` is
# on a rejected control too, so a class does mark the state, but it carries no colour of its own:
# what it does is admit the control to daisyUI's rule, which then reads `aria-invalid`.
#
# This is a deviation, and worth naming as one. Rails' validations guide documents *customising*
# this proc as the way to change how errors are presented, so rendering the message from here is
# the route it points at. That route cannot reach the layout the wireframes ask for: the proc runs
# once for the label and once for the control, and the `instance` it receives says which attribute
# it belongs to but not which of the two tags it holds, so a proc that appended the message would
# emit it twice with no way to suppress either. Hence the message is rendered once, by the builder,
# and this hook is left with nothing to do.
