import { Controller } from "@hotwired/stimulus"

// WHY: the button itself says the text was copied and turns back after two seconds, so a second copy shows again; the status line carries the same news to a screen reader, and shows only when the copy fails.
export default class extends Controller {
  static targets = [ "button", "idle", "done", "status" ]
  static values = { content: String, copied: String, failed: String }
  static classes = [ "idle", "done" ]

  disconnect() {
    clearTimeout(this.timer)
  }

  async copy() {
    clearTimeout(this.timer)

    try {
      await navigator.clipboard.writeText(this.contentValue)
      this.#mark(true)
      this.#say(this.copiedValue, { visible: false })
      this.timer = setTimeout(() => this.#reset(), 2000)
    } catch {
      this.#say(this.failedValue, { visible: true })
    }
  }

  #reset() {
    this.#mark(false)
    this.#say("", { visible: false })
  }

  #mark(copied) {
    this.idleTarget.hidden = copied
    this.doneTarget.hidden = !copied
    this.idleClasses.forEach(name => this.buttonTarget.classList.toggle(name, !copied))
    this.doneClasses.forEach(name => this.buttonTarget.classList.toggle(name, copied))
  }

  #say(text, { visible }) {
    this.statusTarget.textContent = text
    this.statusTarget.classList.toggle("sr-only", !visible)
  }
}
