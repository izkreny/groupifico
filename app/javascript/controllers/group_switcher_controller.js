import { Controller } from "@hotwired/stimulus"

// Only the opening needs script: Escape, the backdrop's `method="dialog"` form and holding focus
// are all `<dialog>`'s own behaviour, which is why the close is heard as the dialog's own event
// rather than wired to a button.
//
// Both chevrons are rendered and one is hidden, so flipping the header's is an attribute toggle
// rather than a path rewrite - `IconsHelper` owns which glyph each meaning draws, and a `d`
// attribute written here would be a second copy of that.
//
// `toggleAttribute` rather than the `hidden` property, because these are `<svg>` elements and
// `hidden` is an `HTMLElement` IDL attribute: `svg.hidden = false` sets a plain JS property and
// leaves `hidden="true"` in the markup. Measured over the DevTools Protocol - `"hidden" in svg`
// answers false and the attribute survives the assignment, where `toggleAttribute` removes it.
export default class extends Controller {
  static targets = ["dialog", "opener", "closed", "opened"]

  connect() {
    this.dialogTarget.addEventListener("close", this.showClosedChevron)
  }

  disconnect() {
    this.dialogTarget.removeEventListener("close", this.showClosedChevron)
  }

  open() {
    this.dialogTarget.showModal()
    this.pointChevron({ open: true })
  }

  showClosedChevron = () => {
    this.pointChevron({ open: false })
  }

  pointChevron({ open }) {
    this.openerTarget.setAttribute("aria-expanded", String(open))
    this.closedTarget.toggleAttribute("hidden", open)
    this.openedTarget.toggleAttribute("hidden", !open)
  }
}
