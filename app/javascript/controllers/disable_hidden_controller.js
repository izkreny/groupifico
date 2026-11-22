import { Controller } from "@hotwired/stimulus"

// WHY: the browser refuses a hidden field that breaks its `required` or `max` and then cancels the submit with nothing on screen, so a field CSS hides is disabled until it shows, which also keeps it out of the post. CSS stays the one thing that decides whether it shows.
export default class extends Controller {
  static targets = ["field"]

  connect() {
    this.update()
  }

  update() {
    this.fieldTargets.forEach((field) => field.toggleAttribute("disabled", !field.checkVisibility()))
  }
}
