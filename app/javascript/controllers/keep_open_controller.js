import { Controller } from "@hotwired/stimulus"

// WHY: a morph sets every attribute back to the server's, and the server draws the roster folded unless asked, so the fold the reader opened would snap shut on every answer they give inside it.
export default class extends Controller {
  keep(event) {
    if (event.target === this.element && event.detail.attributeName === "open") event.preventDefault()
  }
}
