import { Controller } from "@hotwired/stimulus"

// WHY: removed rather than hidden, because a flash says something about the request that just ran and has nothing left to say once read; the next visit renders its own.
export default class extends Controller {
  remove() {
    this.element.remove()
  }
}
