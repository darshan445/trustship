import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.timeoutId = window.setTimeout(() => {
      this.element.classList.add("opacity-0")
      window.setTimeout(() => this.element.remove(), 400)
    }, 3000)
  }

  disconnect() {
    window.clearTimeout(this.timeoutId)
  }
}
