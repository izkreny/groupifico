import { Controller } from "@hotwired/stimulus"

// WHY: a row that scrolls sideways starts at its left edge, which can leave the open item cut off on a narrow screen; this centres it on load, as basecamp_fizzy's scroll-to controller does.
export default class extends Controller {
  static targets = [ "target" ]

  connect() {
    if (this.hasTargetTarget) {
      this.element.scrollTo({ left: this.targetTarget.offsetLeft - this.element.offsetWidth / 2 + this.targetTarget.offsetWidth / 2, behavior: "instant" })
    }
  }
}
