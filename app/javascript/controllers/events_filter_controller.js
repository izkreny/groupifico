import { Controller } from "@hotwired/stimulus"

// WHY: the count is a Turbo Frame pointed at the events list's own URL carrying the sheet's picks, which `EventsController#index` reads for that request alone, so it counts with the very query the list would run and saves nothing.
export default class extends Controller {
  static targets = ["count"]
  static values = { url: String }

  // WHY: the styleguide's copies leave the URL out, because their namespaced frames have no match in the list's response and would read "Content missing".
  refresh() {
    if (!this.urlValue) return

    const picks = new URLSearchParams(new FormData(this.element))
    picks.delete("_method")
    picks.delete("authenticity_token")
    this.countTarget.src = `${this.urlValue}?${picks}`
  }

  // WHY: resets the sheet's inputs rather than submitting, because nothing is applied until the sheet is, and a native reset would return to what was applied rather than to Upcoming with no filters.
  reset() {
    for (const input of this.element.querySelectorAll("input[type=checkbox]")) input.checked = false
    this.element.querySelector("input[name=scope][value='']").checked = true
    this.refresh()
  }
}
