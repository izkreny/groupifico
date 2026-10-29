import { Controller } from "@hotwired/stimulus"

// WHY: a morph moves rows, re-sorting the roster or dropping a row's question, and the browser's scroll anchoring follows whichever row moved, so the view would jump; this puts the view back where it was when the button was pressed.
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
