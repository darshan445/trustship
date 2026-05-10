import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["productSelect", "productId", "productName", "amount"]
  static values = { ordersPath: String }

  connect() {
    this._onKeydown = this._onKeydown.bind(this)
    document.addEventListener("keydown", this._onKeydown)
    document.body.classList.add("overflow-hidden")

    const first = this.element.querySelector("input:not([type=hidden]), select, textarea")
    if (first) first.focus()
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKeydown)
    document.body.classList.remove("overflow-hidden")
  }

  close() {
    const frame = document.getElementById("new_order_modal")
    const onOrdersIndex = document.getElementById("orders-index-page")

    if (frame && onOrdersIndex) {
      frame.innerHTML = ""
    } else if (window.Turbo) {
      Turbo.visit(this.ordersPathValue || "/orders")
    } else {
      window.location.href = this.ordersPathValue || "/orders"
    }
    document.body.classList.remove("overflow-hidden")
  }

  backdropClick(event) {
    if (event.target === event.currentTarget) this.close()
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  productChanged() {
    if (!this.hasProductSelectTarget) return

    const select = this.productSelectTarget
    const option = select.selectedOptions[0]

    if (!option?.value) {
      if (this.hasProductIdTarget) this.productIdTarget.value = ""
      if (this.hasProductNameTarget) this.productNameTarget.value = ""
      return
    }

    if (this.hasProductIdTarget) this.productIdTarget.value = option.value
    if (this.hasProductNameTarget) this.productNameTarget.value = option.dataset.name || ""
    if (this.hasAmountTarget && option.dataset.price) {
      this.amountTarget.value = option.dataset.price
    }
  }

  _onKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
    }
  }
}
