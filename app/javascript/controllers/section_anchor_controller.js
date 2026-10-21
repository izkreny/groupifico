import { Controller } from "@hotwired/stimulus"

// WHY: `scroll: :preserve` keeps the pixel offset through a morph, but a switch draws or drops gated sections above it, so the same offset can land sections away. This keeps the section that was in view where it was, or the first one after it that survives.
// WHY: the anchor lives at module scope rather than on the controller, so it outlives a morph that reconnects the controller.
let anchor = null

export default class extends Controller {
  static targets = ["section"]

  // WHY: the first section that begins in view rather than the one crossing the top edge, whose last lines are usually all that shows of it; the crossing one only when a section fills the viewport.
  remember() {
    const sections = this.sectionTargets
    const begins = sections.find(section => this.#top(section) >= 0 && this.#top(section) < window.innerHeight)
    const anchored = begins || sections.find(section => section.getBoundingClientRect().bottom > 0)

    if (anchored) {
      anchor = { titles: sections.slice(sections.indexOf(anchored)).map(section => section.dataset.title), top: this.#top(anchored) }
    }
  }

  restore() {
    if (anchor) {
      const section = anchor.titles.map(title => this.sectionTargets.find(section => section.dataset.title === title)).find(Boolean)

      if (section) window.scrollBy(0, this.#top(section) - anchor.top)
      anchor = null
    }
  }

  #top(section) {
    return section.getBoundingClientRect().top
  }
}
