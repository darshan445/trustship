import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "labelOpen", "labelClose", "iconOpen", "iconClose"]

  toggle(event) {
    event.preventDefault()
    this.panelTarget.classList.toggle("hidden")
    this.labelOpenTarget.classList.toggle("hidden")
    this.labelCloseTarget.classList.toggle("hidden")
    this.iconOpenTarget.classList.toggle("hidden")
    this.iconCloseTarget.classList.toggle("hidden")
  }
}
