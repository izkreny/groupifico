import { Controller } from "@hotwired/stimulus"

// WHY: the button itself says the link was copied and turns back after two seconds, so a second copy shows again; the status line carries the same news to a screen reader, and shows only when the copy fails.
export default class extends Controller {
  static targets = [ "source", "button", "idle", "done", "status" ]

  disconnect() {
    clearTimeout(this.timer)
  }

  async copy() {
    clearTimeout(this.timer)

    try {
      await navigator.clipboard.writeText(this.sourceTarget.value)
      this.#mark(true)
      this.#say("Link copied", { visible: false })
      this.timer = setTimeout(() => this.#reset(), 2000)
    } catch {
      this.#say("Couldn't copy. Select the link and copy it yourself.", { visible: true })
    }
  }

  #reset() {
    this.#mark(false)
    this.#say("", { visible: false })
  }

  #mark(copied) {
    this.idleTarget.hidden = copied
    this.doneTarget.hidden = !copied
    this.buttonTarget.classList.toggle("btn-primary", !copied)
    this.buttonTarget.classList.toggle("btn-secondary", copied)
  }

  #say(text, { visible }) {
    this.statusTarget.textContent = text
    this.statusTarget.classList.toggle("sr-only", !visible)
  }
}
