import { Controller } from "@hotwired/stimulus"

// WHY: the count is a Turbo Frame pointed at the events list's own URL carrying the sheet's picks, so it counts with the very query applying the sheet would run.
export default class extends Controller {
  static targets = ["count", "pick"]
  static values = { url: String }

  // WHY: Back restores the list from Turbo's snapshot without a request, and a snapshot copies ticked boxes and a fetched count as they stood, so unapplied picks are undone before the page is cached. The count goes back to the one standing before the first pick, read then rather than on connect, because answering a row in place redraws it without reconnecting.
  restore() {
    this.element.reset()
    if (this.drawnCount === undefined) return

    this.countTarget.removeAttribute("src")
    this.countTarget.innerHTML = this.drawnCount
    this.drawnCount = undefined
  }

  // WHY: the styleguide's copies leave the URL out, because their namespaced frames have no match in the list's response and would read "Content missing".
  refresh() {
    if (!this.urlValue) return

    this.drawnCount ??= this.countTarget.innerHTML
    const picks = new URLSearchParams(new FormData(this.element))
    this.countTarget.src = `${this.urlValue}?${picks}`
  }

  // WHY: unticks the sheet's picks rather than submitting, because nothing is applied until the sheet is, and a native reset would return to what was applied rather than to no filters.
  clear() {
    for (const pick of this.pickTargets) pick.checked = false
    this.refresh()
  }
}
