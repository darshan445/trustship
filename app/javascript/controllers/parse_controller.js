import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.originalButtonHtml = this.hasButtonTarget ? this.buttonTarget.innerHTML : ""
    this.onSubmitStart = this.onSubmitStart.bind(this)
    this.onFrameLoad = this.onFrameLoad.bind(this)
    this.element.addEventListener("turbo:submit-start", this.onSubmitStart)
    document.addEventListener("turbo:frame-load", this.onFrameLoad)
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-start", this.onSubmitStart)
    document.removeEventListener("turbo:frame-load", this.onFrameLoad)
  }

  onSubmitStart(event) {
    if (event.target !== this.element) return
    if (!this.hasButtonTarget) return
    this.buttonTarget.disabled = true
    this.buttonTarget.innerHTML = "Parsing..."
    this.buttonTarget.classList.add("animate-pulse")
  }

  onFrameLoad(event) {
    if (event.target.id !== "order_form") return
    this.resetButton()
  }

  resetButton() {
    if (!this.hasButtonTarget) return
    this.buttonTarget.disabled = false
    this.buttonTarget.innerHTML = this.originalButtonHtml
    this.buttonTarget.classList.remove("animate-pulse")
  }
}
