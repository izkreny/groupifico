import { Controller } from "@hotwired/stimulus"

// WHY: a morph re-sorts the roster, and the browser's scroll anchoring follows whichever row it moved, so the view would jump to where the answered row lands; this puts the view back where it was when the button was pressed.
export default class extends Controller {
  hold() {
    this.top = window.scrollY
  }

  restore() {
    if (this.top === undefined) return

    window.scrollTo(0, this.top)
    this.top = undefined
  }
}
