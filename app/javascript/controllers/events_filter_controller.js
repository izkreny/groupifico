import { Controller } from "@hotwired/stimulus"

// The events filter sheet's count and its Reset. The count is a Turbo Frame pointed at the events
// list's own URL carrying the sheet's picks, which `EventsController#index` reads for that request
// alone, so it counts with the very query the list would run and saves nothing.
export default class extends Controller {
  static targets = ["count"]
  static values = { url: String }

  refresh() {
    const picks = new URLSearchParams(new FormData(this.element))
    picks.delete("_method")
    picks.delete("authenticity_token")
    this.countTarget.src = `${this.urlValue}?${picks}`
  }

  // Upcoming with no filters, in the sheet only: nothing is applied until the sheet is submitted.
  reset() {
    for (const input of this.element.querySelectorAll("input[type=checkbox]")) input.checked = false
    this.element.querySelector("input[name=scope][value='']").checked = true
    this.refresh()
  }
}
