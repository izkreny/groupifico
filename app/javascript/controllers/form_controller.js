import { Controller } from "@hotwired/stimulus"

// Submits the form it is attached to, for a control that navigates on change rather than through a
// button beside it. It knows nothing about which form or which control, which is why it is named
// after the element it acts on rather than after the screen that first wanted it.
//
// With JavaScript off the control is inert: there is no submit button to fall back to, and adding
// one would put a second thing to press beside a control that already means "go".
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
