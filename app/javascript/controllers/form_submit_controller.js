import { Controller } from "@hotwired/stimulus"

// Disables the submit button and shows a loading indicator while a Turbo
// form is in flight. Prevents accidental double-submissions.
//
// Usage: data-controller="form-submit" on the <form> element.
// The submit button should have data-form-submit-target="button".
export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.element.addEventListener("turbo:submit-start", this.disable.bind(this))
    this.element.addEventListener("turbo:submit-end", this.enable.bind(this))
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-start", this.disable.bind(this))
    this.element.removeEventListener("turbo:submit-end", this.enable.bind(this))
  }

  disable() {
    this.buttonTargets.forEach(btn => {
      btn.disabled = true
      btn.dataset.originalText = btn.textContent
      btn.textContent = "Saving…"
    })
  }

  enable() {
    this.buttonTargets.forEach(btn => {
      btn.disabled = false
      if (btn.dataset.originalText) btn.textContent = btn.dataset.originalText
    })
  }
}
