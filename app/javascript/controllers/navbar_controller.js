import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this._outside = this._outside.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this._outside, true)
  }

  toggle(event) {
    event.stopPropagation()
    if (this.menuTarget.classList.contains("hidden")) {
      this.menuTarget.classList.remove("hidden")
      queueMicrotask(() => document.addEventListener("click", this._outside, true))
    } else {
      this._hide()
    }
  }

  close() {
    this._hide()
  }

  _hide() {
    this.menuTarget.classList.add("hidden")
    document.removeEventListener("click", this._outside, true)
  }

  _outside(event) {
    if (!this.element.contains(event.target)) {
      this._hide()
    }
  }
}
