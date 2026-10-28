import { Controller } from "@hotwired/stimulus"

// WHY: the folds live in the browser rather than in the markup, because a member switch morphs the page back to the server's every-section-open and a live reload redraws it, and either would unfold what the reader folded.
const key = "styleguide-folded"

export default class extends Controller {
  static targets = ["details"]

  connect() {
    this.restore()
  }

  restore() {
    this.detailsTarget.open = !this.#folded().includes(this.element.dataset.title)
  }

  remember() {
    const others = this.#folded().filter(title => title !== this.element.dataset.title)

    this.#store(this.detailsTarget.open ? others : [...others, this.element.dataset.title])
  }

  // WHY: storage can be unavailable or hold garbage, in a private window or with site data blocked, and the page then simply opens every section.
  #folded() {
    try {
      return JSON.parse(localStorage.getItem(key)) || []
    } catch {
      return []
    }
  }

  #store(titles) {
    try {
      localStorage.setItem(key, JSON.stringify(titles))
    } catch {}
  }
}
