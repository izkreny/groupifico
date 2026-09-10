import { Controller } from "@hotwired/stimulus"

// Opening is the only thing about the sheet that needs JavaScript: the secondary and the backdrop
// are `<form method="dialog">`, which the browser answers by closing the dialog and turbo-rails
// leaves alone, and Escape is native to `showModal()`.
export default class extends Controller {
  static targets = ["sheet", "trigger"]

  // The promise of a dialog is made here rather than in the markup, because with JavaScript off
  // there is no dialog to promise: the trigger posts the delete on the first click, and a screen
  // reader announcing a confirmation step that never arrives is worse than announcing none.
  connect() {
    this.triggerTarget.setAttribute("aria-haspopup", "dialog")
    this.triggerTarget.setAttribute("aria-controls", this.sheetTarget.id)
  }

  // The trigger is an ordinary `method: :delete` form, so with JavaScript off it submits the delete
  // straight away. The sheet's primary submits that same form, and its event bubbles back through
  // here, which is what the already-open sheet stands guard over.
  open(event) {
    if (this.sheetTarget.open) return

    event.preventDefault()
    this.sheetTarget.showModal()
  }
}
