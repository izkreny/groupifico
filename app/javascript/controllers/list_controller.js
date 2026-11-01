import { Controller } from "@hotwired/stimulus"

// The submit waits for a tick that differs from what the screen drew, which no server render can
// know: the ticks change with every press and nothing is posted until the submit.
export default class extends Controller {
  static targets = ["tick", "submit"]

  // The server renders the button enabled, so the screen still submits with JavaScript off. It
  // only becomes conditional once this controller is here to undo that.
  connect() {
    this.update()
  }

  update() {
    this.submitTarget.disabled = this.tickTargets.every((tick) => tick.checked === tick.defaultChecked)
  }
}
