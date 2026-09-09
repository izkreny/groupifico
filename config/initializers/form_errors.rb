Rails.application.config.action_view.field_error_proc = ->(html_tag, _instance) { html_tag }

# Rails wraps every tag belonging to an invalid attribute in `<div class="field_with_errors">`, and
# `ActiveModelInstanceTag` routes the label and the control through that proc separately, so one
# rejected attribute yields two wrappers. Both sit inside the field's own vertical layout and break
# it, and neither is what marks the control invalid: `AppFormBuilder#field` does that with
# `aria-invalid`, `aria-describedby` and daisyUI's `-error` colour, which a screen reader can read
# and a wrapper div cannot.
