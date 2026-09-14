import { Controller } from "@hotwired/stimulus"

// The sheet's primary stays disabled until the field reads the word exactly. The server renders it
// disabled, which is safe where `invite_controller.js` could not afford it: the primary lives in a
// `<dialog>` only JavaScript opens, so with JavaScript off there is no primary to strand.
export default class extends Controller {
  static targets = ["field", "primary"]
  static values = { word: String }

  // A snapshot Turbo restores keeps what was typed, so the button is made to agree with the field
  // on arrival rather than only on the next keystroke.
  connect() {
    this.compare()
  }

  compare() {
    this.primaryTarget.disabled = this.fieldTarget.value !== this.wordValue
  }
}
