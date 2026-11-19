import { Controller } from "@hotwired/stimulus"

// WHY: a cut-off label is the only sign that a row scrolls sideways, and where the screen's edge falls decides whether any label is cut, so an arrow marks each end that hides more; the owner's pick on #486, after Carbon's tabs.
export default class extends Controller {
  static targets = [ "row", "previous", "next" ]

  connect() {
    this.update()
  }

  update() {
    const row = this.rowTarget
    this.previousTarget.hidden = row.scrollLeft <= 0
    this.nextTarget.hidden = row.scrollLeft + row.clientWidth >= row.scrollWidth - 1
  }

  previous() {
    this.#scrollBy(-1)
  }

  next() {
    this.#scrollBy(1)
  }

  #scrollBy(direction) {
    const row = this.rowTarget
    row.scrollBy({ left: direction * row.scrollWidth / row.children.length, behavior: "smooth" })
  }
}
