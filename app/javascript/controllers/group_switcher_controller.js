import { Controller } from "@hotwired/stimulus"

// Heroicons outline chevron-up and chevron-down. Literals here rather than two whole icons swapped
// in, because the button is what carries the accessible name and replacing its contents would take
// the name with it. #238's icon helper is where these stop being literals.
const UP = "m4.5 15.75 7.5-7.5 7.5 7.5"
const DOWN = "m19.5 8.25-7.5 7.5-7.5-7.5"

// Opens the group switcher sheet and flips the header chevron while it is open.
//
// Only the opening needs script. Closing on Escape, closing on the backdrop's `method="dialog"`
// form and holding focus are all `<dialog>`'s own behaviour, so nothing here reimplements them -
// which is why the close is heard as the dialog's own event rather than wired to a button.
export default class extends Controller {
  static targets = ["dialog", "opener"]

  connect() {
    this.dialogTarget.addEventListener("close", this.pointChevronDown)
  }

  disconnect() {
    this.dialogTarget.removeEventListener("close", this.pointChevronDown)
  }

  open() {
    this.dialogTarget.showModal()
    this.openerTarget.setAttribute("aria-expanded", "true")
    this.chevron.setAttribute("d", UP)
  }

  pointChevronDown = () => {
    this.openerTarget.setAttribute("aria-expanded", "false")
    this.chevron.setAttribute("d", DOWN)
  }

  get chevron() {
    return this.openerTarget.querySelector("path")
  }
}
