import { Controller } from "@hotwired/stimulus"

// WHY: each pick replaces a file input's list, so the picked files are kept here and handed back to the input after every change, which is what lets a member add screenshots one at a time.
export default class extends Controller {
  static targets = [ "input", "add", "template", "thumbnail", "error" ]
  static values = { limit: Number, maxSize: Number, types: Array, errors: Object }

  connect() {
    this.picked = new DataTransfer()
  }

  // WHY: handing the list back to the input can fire another change, so only files not already kept are taken, and nothing is redrawn when none were.
  add() {
    const kept = Array.from(this.picked.files)
    const fresh = Array.from(this.inputTarget.files).filter(file => !kept.includes(file))
    const refusals = fresh.map(file => this.#refusal(file))

    fresh.filter((file, index) => !refusals[index]).slice(0, this.limitValue - kept.length).forEach(file => this.picked.items.add(file))

    if (fresh.length > 0) {
      this.#showError(refusals.filter(Boolean).join(" "))
      this.#render()
    }
  }

  // WHY: Turbo caches the page as drawn and restores it on Back, but `connect` starts the kept list empty, so the snapshot must hold no thumbnails either.
  reset() {
    this.picked = new DataTransfer()
    this.#showError("")
    this.#render()
  }

  remove(event) {
    this.picked.items.remove(this.thumbnailTargets.indexOf(event.currentTarget.closest("[data-screenshots-target~=thumbnail]")))

    this.#render()
  }

  // WHY: the same rules the model applies on save, so a file it would refuse never joins the form and the others survive; the model still sniffs the bytes, where this can only read the declared type.
  #refusal(file) {
    if (/^image\/hei[cf]$/.test(file.type) || /\.hei[cf]$/i.test(file.name)) return this.#error("heic", file)
    if (!this.typesValue.includes(file.type)) return this.#error("not_image", file)
    if (file.size > this.maxSizeValue) return this.#error("too_large", file)
  }

  #error(kind, file) {
    return this.errorsValue[kind].replace("%{name}", file.name)
  }

  #showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.hidden = message === ""
  }

  #render() {
    this.thumbnailTargets.forEach(thumbnail => {
      URL.revokeObjectURL(thumbnail.querySelector("img").src)
      thumbnail.remove()
    })

    Array.from(this.picked.files).forEach((file, index) => {
      const thumbnail = this.templateTarget.content.firstElementChild.cloneNode(true)
      thumbnail.querySelector("img").src = URL.createObjectURL(file)
      thumbnail.querySelector("button").setAttribute("aria-label", `Remove screenshot ${index + 1}`)
      this.addTarget.before(thumbnail)
    })

    this.inputTarget.files = this.picked.files
    this.addTarget.hidden = this.picked.items.length >= this.limitValue
  }
}
