import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "source", "status" ]

  async copy() {
    try {
      await navigator.clipboard.writeText(this.sourceTarget.value)
      this.statusTarget.textContent = "Copied"
    } catch {
      this.statusTarget.textContent = "Couldn't copy. Select the link and copy it yourself."
    }
  }
}
