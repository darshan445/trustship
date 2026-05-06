import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "message"]
  static values = { orderId: String }

  async save() {
    const productId = this.selectTarget.value
    if (!productId) return

    this.messageTarget.textContent = "Linking product..."
    try {
      const response = await fetch(`/orders/${this.orderIdValue}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content || ""
        },
        body: JSON.stringify({ product_id: productId })
      })

      if (!response.ok) {
        const payload = await response.json().catch(() => ({}))
        throw new Error(payload.error || "Unable to link product")
      }

      this.messageTarget.textContent = "Product linked successfully."
      window.location.reload()
    } catch (error) {
      this.messageTarget.textContent = error.message
    }
  }
}
