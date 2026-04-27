import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  connect() {
    this._onKeydown = this._onKeydown.bind(this)
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKeydown)
    document.body.classList.remove("overflow-hidden")
  }

  open() {
    this.modalTarget.classList.remove("hidden")
    this.modalTarget.classList.add(
      "flex",
      "flex-col",
      "justify-end",
      "sm:flex-row",
      "sm:items-center",
      "sm:justify-center"
    )
    document.body.classList.add("overflow-hidden")
    document.addEventListener("keydown", this._onKeydown)
    this._trapFocus()
  }

  close() {
    this.modalTarget.classList.add("hidden")
    this.modalTarget.classList.remove(
      "flex",
      "flex-col",
      "justify-end",
      "sm:flex-row",
      "sm:items-center",
      "sm:justify-center"
    )
    document.body.classList.remove("overflow-hidden")
    document.removeEventListener("keydown", this._onKeydown)
  }

  backdropClick(event) {
    if (event.target === this.modalTarget) {
      this.close()
    }
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  _onKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
    }
  }

  _trapFocus() {
    const focusable = this.modalTarget.querySelector(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    )
    if (focusable) focusable.focus()
  }
}
