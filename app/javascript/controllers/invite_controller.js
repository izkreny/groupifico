import { Controller } from "@hotwired/stimulus"

// The submit says how many people it is about to invite, which the frame draws and no server
// render can know: the count changes with every tick and nothing is posted until the submit.
export default class extends Controller {
  static targets = ["tick", "label", "submit"]

  // The server renders the label with no count and the button enabled, so the screen still submits
  // with JavaScript off. Both only become conditional once this controller is here to undo them.
  connect() {
    this.count()
  }

  count() {
    const ticked = this.tickTargets.filter((tick) => tick.checked).length

    this.labelTarget.textContent = ticked === 0 ? "Invite" : `Invite ${ticked} ${ticked === 1 ? "person" : "people"}`
    this.submitTarget.disabled = ticked === 0
  }
}
