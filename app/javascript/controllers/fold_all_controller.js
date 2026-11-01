import { Controller } from "@hotwired/stimulus"

// WHY: it only sets each section's `open`, because the `toggle` that fires then is what the `fold` controller already listens to, so every section remembers its fold exactly as a click would leave it.
export default class extends Controller {
  collapse() {
    this.#sections().forEach(details => details.open = false)
  }

  expand() {
    this.#sections().forEach(details => details.open = true)
  }

  #sections() {
    return document.querySelectorAll("[data-controller~='fold'] > details")
  }
}
