import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["feedback"]
  static values = { text: String }

  copy(event) {
    event.preventDefault()
    navigator.clipboard.writeText(this.textValue).then(() => {
      if (this.hasFeedbackTarget) {
        this.feedbackTarget.textContent = "Copied!"
        clearTimeout(this._feedbackTimer)
        this._feedbackTimer = setTimeout(() => {
          this.feedbackTarget.textContent = ""
        }, 2000)
      }
    })
  }
}
