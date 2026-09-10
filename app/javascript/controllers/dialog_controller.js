import { Controller } from "@hotwired/stimulus"

// Opening is the only thing about the sheet that needs JavaScript: the secondary and the backdrop
// are `<form method="dialog">`, which the browser answers by closing the dialog and turbo-rails
// leaves alone, and Escape is native to `showModal()`.
export default class extends Controller {
  static targets = ["sheet"]

  // The trigger is an ordinary `method: :delete` form, so with JavaScript off it submits the delete
  // straight away. The sheet's primary submits that same form, and its event bubbles back through
  // here, which is what the already-open sheet stands guard over.
  open(event) {
    if (this.sheetTarget.open) return

    event.preventDefault()
    this.sheetTarget.showModal()
  }

  // Confirming redirects with the sheet still open, so the snapshot Turbo caches on the way out
  // would come back on a back navigation as a panel nobody opened.
  close() {
    this.sheetTarget.close()
  }
}
