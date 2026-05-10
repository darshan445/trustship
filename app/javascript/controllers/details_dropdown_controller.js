import { Controller } from "@hotwired/stimulus"

// Closes a <details> menu when the user clicks or taps outside it (native details
// only toggle via summary, not backdrop dismiss).
export default class extends Controller {
  connect() {
    this._onPointerDown = this._onPointerDown.bind(this)
    document.addEventListener("pointerdown", this._onPointerDown, true)
  }

  disconnect() {
    document.removeEventListener("pointerdown", this._onPointerDown, true)
  }

  _onPointerDown(event) {
    if (!this.element.open) return
    if (this.element.contains(event.target)) return

    this.element.removeAttribute("open")
  }
}
