import { Controller } from "@hotwired/stimulus"

// WHY: a `<details>` opens and closes from its own summary alone, so without this a click elsewhere or Escape would leave the menu hanging over the page.
export default class extends Controller {
  close(event) {
    if (!this.element.open) return

    if (event.type === "keydown") {
      if (event.key !== "Escape") return

      this.element.open = false
      this.element.querySelector("summary").focus()
    } else if (!this.element.contains(event.target)) {
      this.element.open = false
    }
  }
}
