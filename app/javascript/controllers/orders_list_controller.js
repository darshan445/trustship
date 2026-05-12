import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search"]

  connect() {
    this.submitDebounced = this.debounce(() => this.submit(), 400)
  }

  search() {
    this.submitDebounced()
  }

  submit() {
    const form = this.element.tagName === "FORM"
      ? this.element
      : this.element.querySelector("form")
    form?.requestSubmit()
  }

  go(event) {
    const url = event.currentTarget.dataset.url
    if (url) Turbo.visit(url)
  }

  stopRowNavigation(event) {
    event.stopPropagation()
  }

  debounce(fn, delay) {
    let timer
    return (...args) => {
      clearTimeout(timer)
      timer = setTimeout(() => fn(...args), delay)
    }
  }
}
