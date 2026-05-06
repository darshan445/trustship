import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search"]

  connect() {
    this.submitDebounced = this.debounce(() => this.submit(), 300)
  }

  search() {
    this.submitDebounced()
  }

  submit() {
    this.element.requestSubmit()
  }

  go(event) {
    const url = event.currentTarget.dataset.url
    if (url) window.location.href = url
  }

  debounce(fn, delay) {
    let timer
    return (...args) => {
      clearTimeout(timer)
      timer = setTimeout(() => fn(...args), delay)
    }
  }
}
