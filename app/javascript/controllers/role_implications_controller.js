import { Controller } from "@hotwired/stimulus"

// Greys the roles a ticked broader role already grants, per `Role#implies?`, whose answers the
// server renders onto each row. Presentation only: a greyed box stays enabled and keeps its state,
// because a disabled box is not posted and a status-only save would then revoke the role it greys.
export default class extends Controller {
  static targets = ["role"]

  connect() {
    this.grey()
  }

  grey() {
    const implied = new Set(this.roleTargets.filter((role) => this.box(role).checked).flatMap((role) => JSON.parse(role.dataset.implies)))

    this.roleTargets.forEach((role) => role.toggleAttribute("data-implied", implied.has(this.box(role).value)))
  }

  box(role) {
    return role.querySelector("input[type=checkbox]")
  }
}
