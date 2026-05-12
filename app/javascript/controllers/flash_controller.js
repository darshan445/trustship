import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.style.transition = "opacity 0.4s ease"
    this.timeoutId = window.setTimeout(() => this.dismiss(), 4000)
  }

  disconnect() {
    window.clearTimeout(this.timeoutId)
  }

  dismiss() {
    this.element.style.opacity = "0"
    window.setTimeout(() => this.element.remove(), 400)
  }
}
