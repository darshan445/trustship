import { Controller } from "@hotwired/stimulus"

// In-app confirmation dialog (replaces window.confirm / turbo_confirm).
// Triggers: buttons with data-action="click->confirm-modal#openFromTrigger"
// and data-confirm-url, data-confirm-title, data-confirm-message.
export default class extends Controller {
  static targets = ["shell", "title", "message", "form", "submitButton"]

  connect() {
    this._onKeydown = this._onKeydown.bind(this)
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKeydown)
    document.body.classList.remove("overflow-hidden")
  }

  openFromTrigger(event) {
    event.preventDefault()
    const el = event.currentTarget
    const url = el.getAttribute("data-confirm-url")
    if (!url) return

    this.formTarget.action = url
    this.titleTarget.textContent =
      el.getAttribute("data-confirm-title") || "Confirm"
    this.messageTarget.textContent =
      el.getAttribute("data-confirm-message") || "Are you sure?"

    const token = document
      .querySelector('meta[name="csrf-token"]')
      ?.getAttribute("content")
    if (token) {
      const input = this.formTarget.querySelector(
        'input[name="authenticity_token"]'
      )
      if (input) input.value = token
    }

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.textContent =
        el.getAttribute("data-confirm-button-label") || "Confirm"
    }

    const deleteMethodField = this.formTarget.querySelector(
      "[data-confirm-modal-delete-field]"
    )
    if (deleteMethodField) {
      deleteMethodField.disabled =
        el.getAttribute("data-confirm-method") !== "delete"
    }

    this.shellTarget.classList.remove("hidden")
    this.shellTarget.classList.add("flex")
    document.body.classList.add("overflow-hidden")
    document.addEventListener("keydown", this._onKeydown)
    queueMicrotask(() => this.submitButtonTarget?.focus())
  }

  close() {
    this.shellTarget.classList.add("hidden")
    this.shellTarget.classList.remove("flex")
    document.body.classList.remove("overflow-hidden")
    document.removeEventListener("keydown", this._onKeydown)
  }

  backdropClick(event) {
    if (event.target === event.currentTarget) this.close()
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  confirmSubmit() {
    if (this.hasSubmitButtonTarget) this.submitButtonTarget.disabled = true
    this.formTarget.requestSubmit()
    this.close()
  }

  _onKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
    }
  }
}
