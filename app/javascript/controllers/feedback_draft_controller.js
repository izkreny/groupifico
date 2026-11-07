import { Controller } from "@hotwired/stimulus"

// WHY: picked screenshots cannot be kept across a page load, but the typed description can, so a member who leaves to take a screenshot finds their words waiting.
export default class extends Controller {
  static targets = [ "description" ]
  static values = { key: String, clear: Boolean }

  connect() {
    if (this.clearValue) {
      localStorage.removeItem(this.keyValue)
    } else if (!this.descriptionTarget.value) {
      this.descriptionTarget.value = localStorage.getItem(this.keyValue) ?? ""
    }
  }

  save() {
    localStorage.setItem(this.keyValue, this.descriptionTarget.value)
  }
}
